#!/usr/bin/env zsh
# threat.zsh — Threat intelligence checks via external APIs
# Services: VirusTotal, Google Safe Browsing, AbuseIPDB

# ---------------------------------------------------------------------------
# _extract_json_int — best-effort integer extraction from JSON by key
# Usage: _extract_json_int "${json}" "malicious"
# ---------------------------------------------------------------------------
_extract_json_int() {
  local json="${1}"
  local key="${2}"
  local val
  val=$(echo "${json}" | grep -Eo "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]+" | head -1 | grep -Eo '[0-9]+')
  echo "${val:-0}"
}

# ---------------------------------------------------------------------------
# _extract_json_str — best-effort string extraction from JSON by key
# Usage: _extract_json_str "${json}" "countryCode"
# ---------------------------------------------------------------------------
_extract_json_str() {
  local json="${1}"
  local key="${2}"
  local val
  val=$(echo "${json}" | sed -nE "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" | head -1)
  echo "${val}"
}

# ---------------------------------------------------------------------------
# _threat_has_keys — verify at least one API key is configured
# ---------------------------------------------------------------------------
_threat_has_keys() {
  [[ -n "${VIRUSTOTAL_API_KEY:-}" || -n "${SAFE_BROWSING_API_KEY:-}" || -n "${ABUSEIPDB_API_KEY:-}" ]]
}

# ---------------------------------------------------------------------------
# _safe_browsing_check_url — check URL via Google Safe Browsing
# Returns:
#   0 if request succeeded and URL appears clean
#   2 if request succeeded and URL is flagged
#   1 on request/config error
# ---------------------------------------------------------------------------
_safe_browsing_check_url() {
  local url="${1}"
  local key="${SAFE_BROWSING_API_KEY:-}"

  [[ -z "${key}" ]] && return 1

  local payload
  payload=$(cat <<EOF
{
  "client": {
    "clientId": "siteinfo-cli",
    "clientVersion": "1.0"
  },
  "threatInfo": {
    "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"],
    "platformTypes": ["ANY_PLATFORM"],
    "threatEntryTypes": ["URL"],
    "threatEntries": [{"url": "${url}"}]
  }
}
EOF
)

  local resp
  resp=$(curl --silent --max-time 20 --connect-timeout 8 \
    --request POST \
    --header "Content-Type: application/json" \
    --data "${payload}" \
    "https://safebrowsing.googleapis.com/v4/threatMatches:find?key=${key}" 2>/dev/null)

  [[ -z "${resp}" ]] && return 1
  echo "${resp}" | grep -q '"matches"' && return 2
  return 0
}

# ---------------------------------------------------------------------------
# run_threat — main threat intelligence function
# Usage: run_threat "https://example.com"
# ---------------------------------------------------------------------------
run_threat() {
  local url="${1}"
  local domain
  domain=$(extract_host "${url}")

  if [[ -z "${domain}" ]]; then
    print_error "Could not extract domain from URL: ${url}"
    return 1
  fi

  print_section "Threat Intelligence — ${domain}"

  if ! _threat_has_keys; then
    print_warning "No threat-intel API keys found"
    print_info "Set one or more keys in .env: VIRUSTOTAL_API_KEY, SAFE_BROWSING_API_KEY, ABUSEIPDB_API_KEY"
    print_section_end
    return 1
  fi

  local risk_points=0

  # ── VirusTotal domain reputation ──────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}VirusTotal${CLR_RESET}\n"
  if [[ -n "${VIRUSTOTAL_API_KEY:-}" ]]; then
    local vt_resp
    vt_resp=$(curl --silent --max-time 20 --connect-timeout 8 \
      --header "x-apikey: ${VIRUSTOTAL_API_KEY}" \
      "https://www.virustotal.com/api/v3/domains/${domain}" 2>/dev/null)

    if [[ -n "${vt_resp}" ]] && ! echo "${vt_resp}" | grep -qi '"error"'; then
      local vt_mal vt_susp vt_harmless vt_undetected
      vt_mal=$(_extract_json_int "${vt_resp}" "malicious")
      vt_susp=$(_extract_json_int "${vt_resp}" "suspicious")
      vt_harmless=$(_extract_json_int "${vt_resp}" "harmless")
      vt_undetected=$(_extract_json_int "${vt_resp}" "undetected")

      print_key_value "Malicious"  "${vt_mal}" "red"
      print_key_value "Suspicious" "${vt_susp}" "yellow"
      print_key_value "Harmless"   "${vt_harmless}" "green"
      print_key_value "Undetected" "${vt_undetected}" "white"

      if (( vt_mal > 0 )); then
        (( risk_points += 45 )) || true
        print_warning "VirusTotal reports malicious detections"
      elif (( vt_susp > 0 )); then
        (( risk_points += 25 )) || true
        print_warning "VirusTotal reports suspicious detections"
      else
        print_success "No malicious/suspicious detections on domain"
      fi
    else
      print_warning "VirusTotal request failed or returned error"
    fi
  else
    print_info "VIRUSTOTAL_API_KEY is not set"
  fi

  # ── Google Safe Browsing URL verdict ──────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Google Safe Browsing${CLR_RESET}\n"
  if [[ -n "${SAFE_BROWSING_API_KEY:-}" ]]; then
    _safe_browsing_check_url "${url}"
    local sb_result=$?
    case "${sb_result}" in
      0)
        print_success "URL not flagged by Safe Browsing"
        ;;
      2)
        print_warning "URL flagged by Safe Browsing"
        (( risk_points += 55 )) || true
        ;;
      *)
        print_warning "Safe Browsing request failed"
        ;;
    esac
  else
    print_info "SAFE_BROWSING_API_KEY is not set"
  fi

  # ── AbuseIPDB IP reputation (first IPv4) ──────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}AbuseIPDB${CLR_RESET}\n"
  if [[ -n "${ABUSEIPDB_API_KEY:-}" ]]; then
    local a_records first_ip
    a_records=$(_dns_query "${domain}" "A")
    first_ip=$(echo "${a_records}" | head -1)

    if [[ -n "${first_ip}" ]]; then
      local ab_resp
      ab_resp=$(curl --silent --max-time 20 --connect-timeout 8 \
        --get "https://api.abuseipdb.com/api/v2/check" \
        --data-urlencode "ipAddress=${first_ip}" \
        --data-urlencode "maxAgeInDays=90" \
        --header "Key: ${ABUSEIPDB_API_KEY}" \
        --header "Accept: application/json" 2>/dev/null)

      if [[ -n "${ab_resp}" ]] && ! echo "${ab_resp}" | grep -qi '"errors"'; then
        local ab_score ab_reports ab_country ab_isp ab_color
        ab_score=$(_extract_json_int "${ab_resp}" "abuseConfidenceScore")
        ab_reports=$(_extract_json_int "${ab_resp}" "totalReports")
        ab_country=$(_extract_json_str "${ab_resp}" "countryCode")
        ab_isp=$(_extract_json_str "${ab_resp}" "isp")

        if (( ab_score >= 50 )); then
          ab_color="red"
        elif (( ab_score >= 10 )); then
          ab_color="yellow"
        else
          ab_color="green"
        fi

        print_key_value "Checked IP" "${first_ip}" "cyan"
        print_key_value "Abuse Score" "${ab_score}/100" "${ab_color}"
        print_key_value "Reports (90d)" "${ab_reports}" "white"
        [[ -n "${ab_country}" ]] && print_key_value "Country" "${ab_country}" "white"
        [[ -n "${ab_isp}" ]] && print_key_value "ISP" "${ab_isp}" "white"

        if (( ab_score >= 50 )); then
          (( risk_points += 35 )) || true
          print_warning "High abuse confidence for hosting IP"
        elif (( ab_score >= 10 )); then
          (( risk_points += 15 )) || true
          print_warning "Moderate abuse confidence for hosting IP"
        else
          print_success "Low abuse confidence for hosting IP"
        fi
      else
        print_warning "AbuseIPDB request failed or returned error"
      fi
    else
      print_info "No IPv4 address found for AbuseIPDB check"
    fi
  else
    print_info "ABUSEIPDB_API_KEY is not set"
  fi

  # ── Overall verdict ────────────────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Threat Verdict${CLR_RESET}\n"
  print_progress_bar "${risk_points}" 100 "Threat Risk"
  if (( risk_points >= 70 )); then
    print_warning "High risk: investigate immediately"
  elif (( risk_points >= 35 )); then
    print_warning "Medium risk: review findings"
  else
    print_success "Low risk based on configured feeds"
  fi

  print_section_end
}
