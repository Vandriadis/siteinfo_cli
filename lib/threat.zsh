#!/usr/bin/env zsh
# threat.zsh — Threat intelligence checks via external APIs
# Services: VirusTotal, Google Safe Browsing, AbuseIPDB, Shodan, IPinfo, urlscan

# ---------------------------------------------------------------------------
# _profile_is_at_least — quick < standard < deep
# ---------------------------------------------------------------------------
_profile_is_at_least() {
  local required="${1}"
  case "${SITEINFO_PROFILE:-standard}" in
    deep)
      return 0
      ;;
    standard)
      [[ "${required}" != "deep" ]]
      return
      ;;
    quick)
      [[ "${required}" == "quick" ]]
      return
      ;;
    *)
      [[ "${required}" == "quick" || "${required}" == "standard" ]]
      return
      ;;
  esac
}

# ---------------------------------------------------------------------------
# _http_cached_get — GET with cache fallback
# Usage: _http_cached_get "svc" "cache-key" "url" "ttl" [curl headers...]
# ---------------------------------------------------------------------------
_http_cached_get() {
  local service="${1}"
  local cache_key="${2}"
  local url="${3}"
  local ttl="${4:-21600}"
  local loading_label="${5:-Loading}"
  shift 5

  local cached
  cached=$(cache_get "${service}" "${cache_key}" "${ttl}")
  if [[ -n "${cached}" ]]; then
    if ! ui_is_compact; then
      print_info "${service}: using cache"
    fi
    echo "${cached}"
    return 0
  fi

  local resp
  resp=$(run_with_spinner "${loading_label}" curl --silent --max-time 20 --connect-timeout 8 "$@" "${url}")
  [[ -n "${resp}" ]] && cache_set "${service}" "${cache_key}" "${resp}"
  echo "${resp}"
}

# ---------------------------------------------------------------------------
# _json_get_int — integer extraction with jq when available
# ---------------------------------------------------------------------------
_json_get_int() {
  local json="${1}"
  local jq_path="${2}"
  local fallback_key="${3}"
  local val=""

  if command -v jq &>/dev/null; then
    val=$(echo "${json}" | jq -r "${jq_path} // 0" 2>/dev/null | head -1)
  fi
  if [[ -z "${val}" || "${val}" == "null" ]]; then
    val=$(_extract_json_int "${json}" "${fallback_key}")
  fi
  echo "${val:-0}"
}

# ---------------------------------------------------------------------------
# _json_get_str — string extraction with jq when available
# ---------------------------------------------------------------------------
_json_get_str() {
  local json="${1}"
  local jq_path="${2}"
  local fallback_key="${3}"
  local val=""

  if command -v jq &>/dev/null; then
    val=$(echo "${json}" | jq -r "${jq_path} // empty" 2>/dev/null | head -1)
  fi
  [[ -z "${val}" || "${val}" == "null" ]] && val=$(_extract_json_str "${json}" "${fallback_key}")
  echo "${val}"
}

# ---------------------------------------------------------------------------
# _json_get_bool — boolean extraction with jq when available
# ---------------------------------------------------------------------------
_json_get_bool() {
  local json="${1}"
  local jq_path="${2}"
  local fallback_key="${3}"
  local val=""

  if command -v jq &>/dev/null; then
    val=$(echo "${json}" | jq -r "${jq_path} // empty" 2>/dev/null | head -1)
  fi
  [[ -z "${val}" || "${val}" == "null" ]] && val=$(_extract_json_bool "${json}" "${fallback_key}")
  echo "${val}"
}

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
# _extract_json_bool — best-effort boolean extraction from JSON by key
# Returns: true | false | empty
# ---------------------------------------------------------------------------
_extract_json_bool() {
  local json="${1}"
  local key="${2}"
  local val
  val=$(echo "${json}" | sed -nE "s/.*\"${key}\"[[:space:]]*:[[:space:]]*(true|false).*/\1/p" | head -1)
  echo "${val}"
}

# ---------------------------------------------------------------------------
# _threat_has_keys — verify at least one API key is configured
# ---------------------------------------------------------------------------
_threat_has_keys() {
  [[ -n "${VIRUSTOTAL_API_KEY:-}" || -n "${SAFE_BROWSING_API_KEY:-}" || -n "${ABUSEIPDB_API_KEY:-}" || \
     -n "${SHODAN_API_KEY:-}" || -n "${IPINFO_API_TOKEN:-}" || -n "${URLSCAN_API_KEY:-}" ]]
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

  local cache_key
  cache_key="safebrowsing|${url}"
  local resp
  resp=$(cache_get "safebrowsing" "${cache_key}" 21600)
  if [[ -z "${resp}" ]]; then
    resp=$(run_with_spinner "Checking Safe Browsing" curl --silent --max-time 20 --connect-timeout 8 \
      --request POST \
      --header "Content-Type: application/json" \
      --data "${payload}" \
      "https://safebrowsing.googleapis.com/v4/threatMatches:find?key=${key}")
    [[ -n "${resp}" ]] && cache_set "safebrowsing" "${cache_key}" "${resp}"
  elif ! ui_is_compact; then
    print_info "safebrowsing: using cache"
  fi

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
    print_info "Set one or more keys in .env: VIRUSTOTAL_API_KEY, SAFE_BROWSING_API_KEY, ABUSEIPDB_API_KEY, SHODAN_API_KEY, IPINFO_API_TOKEN, URLSCAN_API_KEY"
    print_section_end
    return 1
  fi

  local risk_points=0
  if ! ui_is_compact; then
    print_info "Threat profile: ${SITEINFO_PROFILE:-standard}"
    if command -v jq &>/dev/null; then
      print_info "JSON parser: jq"
    else
      print_info "JSON parser: fallback (grep/sed)"
    fi
  fi

  # ── VirusTotal domain reputation ──────────────────────────────────────────
  if _profile_is_at_least "standard"; then
    print_separator
    printf "  ${CLR_BOLD_YELLOW}VirusTotal${CLR_RESET}\n"
  if [[ -n "${VIRUSTOTAL_API_KEY:-}" ]]; then
    local vt_resp
    vt_resp=$(_http_cached_get "virustotal" "domain|${domain}" "https://www.virustotal.com/api/v3/domains/${domain}" 21600 "Checking VirusTotal" \
      --header "x-apikey: ${VIRUSTOTAL_API_KEY}")

    if [[ -n "${vt_resp}" ]] && ! echo "${vt_resp}" | grep -qi '"error"'; then
      local vt_mal vt_susp vt_harmless vt_undetected
      vt_mal=$(_json_get_int "${vt_resp}" ".data.attributes.last_analysis_stats.malicious" "malicious")
      vt_susp=$(_json_get_int "${vt_resp}" ".data.attributes.last_analysis_stats.suspicious" "suspicious")
      vt_harmless=$(_json_get_int "${vt_resp}" ".data.attributes.last_analysis_stats.harmless" "harmless")
      vt_undetected=$(_json_get_int "${vt_resp}" ".data.attributes.last_analysis_stats.undetected" "undetected")

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
  else
    print_info "VirusTotal skipped (quick profile)"
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

  # ── Host intelligence: Shodan + IPinfo ────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Host Intelligence${CLR_RESET}\n"
  local host_ip
  host_ip=$(echo "$(_dns_query "${domain}" "A")" | head -1)

  if [[ -z "${host_ip}" ]]; then
    print_info "No IPv4 address found for host intelligence checks"
  else
    # IPinfo context
    if _profile_is_at_least "standard" && [[ -n "${IPINFO_API_TOKEN:-}" ]]; then
      local ipi_resp ipi_country ipi_org ipi_hostname ipi_bogon
      ipi_resp=$(_http_cached_get "ipinfo" "ip|${host_ip}" "https://ipinfo.io/${host_ip}?token=${IPINFO_API_TOKEN}" 21600 "Checking IPinfo")

      if [[ -n "${ipi_resp}" ]]; then
        ipi_country=$(_json_get_str "${ipi_resp}" ".country" "country")
        ipi_org=$(_json_get_str "${ipi_resp}" ".org" "org")
        ipi_hostname=$(_json_get_str "${ipi_resp}" ".hostname" "hostname")
        ipi_bogon=$(_json_get_bool "${ipi_resp}" ".bogon" "bogon")

        print_key_value "Host IP" "${host_ip}" "cyan"
        [[ -n "${ipi_country}" ]] && print_key_value "Country" "${ipi_country}" "white"
        [[ -n "${ipi_org}" ]] && print_key_value "ASN / Org" "${ipi_org}" "white"
        [[ -n "${ipi_hostname}" ]] && print_key_value "Reverse Host" "${ipi_hostname}" "white"

        if [[ "${ipi_bogon}" == "true" ]]; then
          (( risk_points += 40 )) || true
          print_warning "IPinfo marks this IP as bogon/special-use"
        fi
      else
        print_warning "IPinfo request failed"
      fi
    else
      if _profile_is_at_least "standard"; then
        print_info "IPINFO_API_TOKEN is not set"
      else
        print_info "IPinfo skipped (quick profile)"
      fi
    fi

    # Shodan exposure
    if _profile_is_at_least "deep" && [[ -n "${SHODAN_API_KEY:-}" ]]; then
        local sh_resp sh_ports_raw sh_ports_count sh_vuln_count sh_org sh_ports_color sh_cve_color
      sh_resp=$(_http_cached_get "shodan" "host|${host_ip}" "https://api.shodan.io/shodan/host/${host_ip}?key=${SHODAN_API_KEY}" 21600 "Checking Shodan")

      if [[ -n "${sh_resp}" ]] && ! echo "${sh_resp}" | grep -qi '"error"'; then
        sh_ports_raw=$(echo "${sh_resp}" | sed -nE 's/.*"ports":[[:space:]]*\[([^]]*)\].*/\1/p' | head -1)
        sh_ports_count=0
        if [[ -n "${sh_ports_raw}" ]]; then
          sh_ports_count=$(echo "${sh_ports_raw}" | tr ',' '\n' | grep -c '[0-9]' 2>/dev/null || echo 0)
        fi
        sh_vuln_count=$(echo "${sh_resp}" | grep -Eo '"CVE-[0-9]{4}-[0-9]+"' | sort -u | wc -l | tr -d ' ')
        sh_org=$(_json_get_str "${sh_resp}" ".org" "org")

        if (( sh_ports_count >= 10 )); then
          sh_ports_color="red"
        elif (( sh_ports_count >= 3 )); then
          sh_ports_color="yellow"
        else
          sh_ports_color="green"
        fi
        if (( sh_vuln_count > 0 )); then
          sh_cve_color="red"
        else
          sh_cve_color="green"
        fi

        print_key_value "Open Ports" "${sh_ports_count}" "${sh_ports_color}"
        [[ -n "${sh_org}" ]] && print_key_value "Shodan Org" "${sh_org}" "white"
        print_key_value "Known CVEs" "${sh_vuln_count}" "${sh_cve_color}"

        if (( sh_vuln_count > 0 )); then
          (( risk_points += 45 )) || true
          print_warning "Shodan reports known CVEs on exposed services"
        elif (( sh_ports_count >= 10 )); then
          (( risk_points += 20 )) || true
          print_warning "High exposed port surface"
        elif (( sh_ports_count >= 3 )); then
          (( risk_points += 10 )) || true
          print_warning "Moderate exposed port surface"
        else
          print_success "Low exposed port surface (Shodan)"
        fi
      else
        print_warning "Shodan request failed or host not indexed"
      fi
    else
      if _profile_is_at_least "deep"; then
        print_info "SHODAN_API_KEY is not set"
      else
        print_info "Shodan skipped (standard/quick profile)"
      fi
    fi
  fi

  # ── urlscan historical signal ─────────────────────────────────────────────
  if _profile_is_at_least "deep"; then
    print_separator
    printf "  ${CLR_BOLD_YELLOW}urlscan${CLR_RESET}\n"
  if [[ -n "${URLSCAN_API_KEY:-}" ]]; then
    local us_resp us_total us_mal_resp us_mal_total

    us_resp=$(_http_cached_get "urlscan" "domain|${domain}|all" "https://urlscan.io/api/v1/search/?q=domain:${domain}&size=1" 21600 "Checking urlscan history" \
      --header "API-Key: ${URLSCAN_API_KEY}")
    us_total=$(_json_get_int "${us_resp}" ".total" "total")

    us_mal_resp=$(_http_cached_get "urlscan" "domain|${domain}|mal" "https://urlscan.io/api/v1/search/?q=domain:${domain}%20AND%20verdicts.overall.malicious:true&size=1" 21600 "Checking malicious verdicts" \
      --header "API-Key: ${URLSCAN_API_KEY}")
    us_mal_total=$(_json_get_int "${us_mal_resp}" ".total" "total")

    print_key_value "Indexed scans" "${us_total}" "white"
    local us_mal_color="green"
    (( us_mal_total > 0 )) && us_mal_color="red"
    print_key_value "Malicious verdicts" "${us_mal_total}" "${us_mal_color}"

    if (( us_mal_total > 0 )); then
      (( risk_points += 30 )) || true
      print_warning "urlscan has malicious verdict(s) for this domain"
    elif (( us_total > 0 )); then
      print_success "No malicious urlscan verdicts found"
    else
      print_info "No urlscan history found for this domain"
    fi
  else
    print_info "URLSCAN_API_KEY is not set"
  fi
  else
    print_info "urlscan skipped (standard/quick profile)"
  fi

  # ── Overall verdict ────────────────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Threat Verdict${CLR_RESET}\n"
  (( risk_points > 100 )) && risk_points=100
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
