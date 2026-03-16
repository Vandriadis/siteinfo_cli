#!/usr/bin/env zsh
# security.zsh — Security headers and cookie analysis module

# ---------------------------------------------------------------------------
# Security headers to check (header name → severity if missing)
# Severity: critical | high | medium | info
# ---------------------------------------------------------------------------
typeset -gA SEC_HEADERS_SEVERITY
SEC_HEADERS_SEVERITY[Strict-Transport-Security]="critical"
SEC_HEADERS_SEVERITY[Content-Security-Policy]="critical"
SEC_HEADERS_SEVERITY[X-Frame-Options]="high"
SEC_HEADERS_SEVERITY[X-Content-Type-Options]="high"
SEC_HEADERS_SEVERITY[Referrer-Policy]="medium"
SEC_HEADERS_SEVERITY[Permissions-Policy]="medium"
SEC_HEADERS_SEVERITY[Cross-Origin-Opener-Policy]="medium"
SEC_HEADERS_SEVERITY[Cross-Origin-Embedder-Policy]="medium"
SEC_HEADERS_SEVERITY[Cross-Origin-Resource-Policy]="medium"
SEC_HEADERS_SEVERITY[X-XSS-Protection]="info"
SEC_HEADERS_SEVERITY[Cache-Control]="info"
SEC_HEADERS_SEVERITY[Expect-CT]="info"

# ---------------------------------------------------------------------------
# Recommended values / documentation notes for each header
# ---------------------------------------------------------------------------
typeset -gA SEC_HEADERS_NOTE
SEC_HEADERS_NOTE[Strict-Transport-Security]="Recommended: max-age=31536000; includeSubDomains; preload"
SEC_HEADERS_NOTE[Content-Security-Policy]="Restricts sources of content — prevents XSS"
SEC_HEADERS_NOTE[X-Frame-Options]="Recommended: DENY or SAMEORIGIN — prevents clickjacking"
SEC_HEADERS_NOTE[X-Content-Type-Options]="Recommended: nosniff — prevents MIME sniffing"
SEC_HEADERS_NOTE[Referrer-Policy]="Recommended: strict-origin-when-cross-origin"
SEC_HEADERS_NOTE[Permissions-Policy]="Controls browser features (camera, microphone, etc.)"
SEC_HEADERS_NOTE[Cross-Origin-Opener-Policy]="Recommended: same-origin — mitigates Spectre attacks"
SEC_HEADERS_NOTE[Cross-Origin-Embedder-Policy]="Required for isolation features (SharedArrayBuffer)"
SEC_HEADERS_NOTE[Cross-Origin-Resource-Policy]="Controls cross-origin resource loading"
SEC_HEADERS_NOTE[X-XSS-Protection]="Legacy header; superseded by CSP"
SEC_HEADERS_NOTE[Cache-Control]="Recommended: no-store for sensitive pages"
SEC_HEADERS_NOTE[Expect-CT]="Certificate Transparency enforcement (deprecated)"

# ---------------------------------------------------------------------------
# _fetch_headers_for_security — get headers from URL
# ---------------------------------------------------------------------------
_fetch_headers_for_security() {
  local url="${1}"
  curl \
    --silent \
    --head \
    --max-time 15 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    --user-agent "${UA_DESKTOP}" \
    "${url}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _get_header_value — extract a specific header value (case-insensitive)
# Usage: val=$(_get_header_value "strict-transport-security" "${headers}")
# ---------------------------------------------------------------------------
_get_header_value() {
  local name="${1}"
  local headers="${2}"
  echo "${headers}" | grep -i "^${name}:" | tail -1 | cut -d: -f2- | sed 's/^ *//' | tr -d '\r'
}

# ---------------------------------------------------------------------------
# _analyze_hsts — evaluate HSTS header quality
# ---------------------------------------------------------------------------
_analyze_hsts() {
  local value="${1}"
  local issues=()

  local max_age
  max_age=$(echo "${value}" | grep -oi 'max-age=[0-9]*' | grep -o '[0-9]*')

  if [[ -z "${max_age}" ]]; then
    issues+=("missing max-age directive")
  elif (( max_age < 15768000 )); then
    issues+=("max-age too short (< 6 months): ${max_age}s")
  fi

  echo "${value}" | grep -qi 'includeSubDomains' || issues+=("missing includeSubDomains")
  echo "${value}" | grep -qi 'preload'           || issues+=("not in preload list (optional but recommended)")

  if (( ${#issues[@]} > 0 )); then
    printf '%s\n' "${issues[@]}"
  fi
}

# ---------------------------------------------------------------------------
# _analyze_csp — evaluate CSP header for common weaknesses
# ---------------------------------------------------------------------------
_analyze_csp() {
  local value="${1}"
  local issues=()

  echo "${value}" | grep -qi "unsafe-inline" && issues+=("contains 'unsafe-inline' — weakens XSS protection")
  echo "${value}" | grep -qi "unsafe-eval"   && issues+=("contains 'unsafe-eval' — weakens XSS protection")
  echo "${value}" | grep -qi "\*"            && issues+=("contains wildcard (*) — overly permissive")
  echo "${value}" | grep -qi "http://"       && issues+=("allows http:// sources — mixed content risk")

  if (( ${#issues[@]} > 0 )); then
    printf '%s\n' "${issues[@]}"
  fi
}

# ---------------------------------------------------------------------------
# _severity_color — return color name for severity level
# ---------------------------------------------------------------------------
_severity_color() {
  case "${1}" in
    critical) echo "red"     ;;
    high)     echo "red"     ;;
    medium)   echo "yellow"  ;;
    info)     echo "white"   ;;
    *)        echo "white"   ;;
  esac
}

# ---------------------------------------------------------------------------
# _severity_badge — return printable badge string
# ---------------------------------------------------------------------------
_severity_badge() {
  local sev="${1}"
  case "${sev}" in
    critical) printf "${CLR_BOLD_RED}[CRITICAL]${CLR_RESET}" ;;
    high)     printf "${CLR_BOLD_RED}[HIGH]    ${CLR_RESET}" ;;
    medium)   printf "${CLR_BOLD_YELLOW}[MEDIUM]  ${CLR_RESET}" ;;
    info)     printf "${CLR_DIM}[INFO]    ${CLR_RESET}" ;;
    *)        printf "${CLR_DIM}[INFO]    ${CLR_RESET}" ;;
  esac
}

# ---------------------------------------------------------------------------
# _check_cookie_security — analyze a Set-Cookie header value
# ---------------------------------------------------------------------------
_check_cookie_security() {
  local raw_cookie="${1}"

  # Extract cookie name (first token before =)
  local cookie_name
  cookie_name=$(echo "${raw_cookie}" | sed 's/^set-cookie: *//i' | cut -d= -f1 | tr -d ' ')

  local flags=()
  local warnings=()

  echo "${raw_cookie}" | grep -qi '\bSecure\b'   && flags+=("Secure") || warnings+=("missing Secure flag")
  echo "${raw_cookie}" | grep -qi '\bHttpOnly\b'  && flags+=("HttpOnly") || warnings+=("missing HttpOnly flag")

  local samesite
  samesite=$(echo "${raw_cookie}" | grep -oi 'SameSite=[A-Za-z]*' | cut -d= -f2)
  if [[ -n "${samesite}" ]]; then
    flags+=("SameSite=${samesite}")
    [[ "${samesite}" == "None" ]] && warnings+=("SameSite=None requires Secure flag")
  else
    warnings+=("missing SameSite attribute")
  fi

  printf "  ${CLR_BOLD_WHITE}Cookie: %s${CLR_RESET}\n" "${cookie_name}"

  if (( ${#flags[@]} > 0 )); then
    printf "    ${CLR_GREEN}Flags:    %s${CLR_RESET}\n" "${flags[*]}"
  fi

  if (( ${#warnings[@]} > 0 )); then
    for w in "${warnings[@]}"; do
      printf "    ${CLR_YELLOW}⚠ %s${CLR_RESET}\n" "${w}"
    done
  else
    printf "    ${CLR_GREEN}✔ All recommended cookie flags are set${CLR_RESET}\n"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# _check_https — verify the site uses HTTPS and check cert basic info
# ---------------------------------------------------------------------------
_check_https() {
  local url="${1}"

  print_separator
  printf "  ${CLR_BOLD_YELLOW}HTTPS / TLS${CLR_RESET}\n"

  if [[ "${url}" == https://* ]]; then
    print_success "Site uses HTTPS"

    # Check certificate expiry using curl
    local cert_info
    cert_info=$(curl --silent --head --max-time 10 --connect-timeout 8 \
      --user-agent "${UA_DESKTOP}" \
      --write-out '%{ssl_verify_result},%{time_appconnect}' \
      --output /dev/null \
      "${url}" 2>/dev/null)

    local ssl_result
    ssl_result=$(echo "${cert_info}" | cut -d, -f1)
    local tls_time
    tls_time=$(echo "${cert_info}" | cut -d, -f2)

    if [[ "${ssl_result}" == "0" ]]; then
      print_success "SSL certificate is valid"
    elif [[ -n "${ssl_result}" && "${ssl_result}" != "0" ]]; then
      print_warning "SSL verification result: ${ssl_result} (0 = valid)"
    fi

    [[ -n "${tls_time}" && "${tls_time}" != "0.000000" ]] && \
      print_key_value "TLS Handshake Time" "${tls_time}s" "white"
  else
    print_warning "Site does not use HTTPS — all data transmitted in plaintext"
    print_info "Consider redirecting to https:// and obtaining an SSL certificate"
  fi
}

# ---------------------------------------------------------------------------
# run_security — main security analysis function
# Usage: run_security "https://example.com"
# ---------------------------------------------------------------------------
run_security() {
  local url="${1}"

  print_section "Security Analysis — ${url}"
  print_info "Fetching security headers..."

  local headers
  headers=$(_fetch_headers_for_security "${url}")

  if [[ -z "${headers}" ]]; then
    print_error "Failed to fetch headers from ${url}"
    print_section_end
    return 1
  fi

  # ── HTTPS Check ──────────────────────────────────────────────────────────
  _check_https "${url}"

  # ── Security Headers ─────────────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Security Headers${CLR_RESET}\n"
  echo ""

  local score=0
  local max_score=0
  local missing_critical=0
  local missing_high=0
  # Declare loop-local variables ONCE before the loop to avoid zsh
  # printing their values when re-declared on subsequent iterations.
  local _sev _note _val _badge _analysis_issues

  local header_order=(
    "Strict-Transport-Security"
    "Content-Security-Policy"
    "X-Frame-Options"
    "X-Content-Type-Options"
    "Referrer-Policy"
    "Permissions-Policy"
    "Cross-Origin-Opener-Policy"
    "Cross-Origin-Embedder-Policy"
    "Cross-Origin-Resource-Policy"
    "X-XSS-Protection"
    "Cache-Control"
    "Expect-CT"
  )

  for header in "${header_order[@]}"; do
    _sev="${SEC_HEADERS_SEVERITY[$header]:-info}"
    _note="${SEC_HEADERS_NOTE[$header]:-}"
    (( max_score++ )) || true

    _val=$(_get_header_value "${header}" "${headers}")

    if [[ -n "${_val}" ]]; then
      (( score++ )) || true
      printf "  ${CLR_BOLD_GREEN}[✔]${CLR_RESET} ${CLR_BOLD_WHITE}%-38s${CLR_RESET}  ${CLR_GREEN}Present${CLR_RESET}\n" "${header}"
      printf "    ${CLR_DIM}%s${CLR_RESET}\n" "${_val:0:90}"

      # Deep analysis for key headers
      _analysis_issues=""
      case "${header}" in
        Strict-Transport-Security)
          _analysis_issues=$(_analyze_hsts "${_val}")
          ;;
        Content-Security-Policy)
          _analysis_issues=$(_analyze_csp "${_val}")
          ;;
      esac

      if [[ -n "${_analysis_issues}" ]]; then
        echo ""
        while IFS= read -r issue; do
          printf "    ${CLR_YELLOW}⚠ %s${CLR_RESET}\n" "${issue}"
        done <<< "${_analysis_issues}"
      fi
      echo ""
    else
      _badge=$(_severity_badge "${_sev}")
      printf "  ${CLR_BOLD_RED}[✖]${CLR_RESET} ${CLR_BOLD_WHITE}%-38s${CLR_RESET}  %s ${CLR_YELLOW}MISSING${CLR_RESET}\n" "${header}" "${_badge}"
      [[ -n "${_note}" ]] && printf "    ${CLR_DIM}%s${CLR_RESET}\n" "${_note}"
      echo ""

      case "${_sev}" in
        critical) (( missing_critical++ )) || true ;;
        high)     (( missing_high++ ))     || true ;;
      esac
    fi
  done

  # ── Cookie Analysis ───────────────────────────────────────────────────────
  local cookies
  cookies=$(echo "${headers}" | grep -i "^set-cookie:" | tr -d '\r')

  if [[ -n "${cookies}" ]]; then
    print_separator
    printf "  ${CLR_BOLD_YELLOW}Cookie Security Analysis${CLR_RESET}\n"
    echo ""
    while IFS= read -r ck; do
      [[ -z "${ck}" ]] && continue
      _check_cookie_security "${ck}"
    done <<< "${cookies}"
  else
    print_separator
    printf "  ${CLR_BOLD_YELLOW}Cookie Security${CLR_RESET}\n"
    print_info "No Set-Cookie headers found in response"
  fi

  # ── Score Summary ─────────────────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Security Score${CLR_RESET}  ${CLR_DIM}%d / %d headers present${CLR_RESET}\n" \
    "${score}" "${max_score}"
  echo ""

  print_progress_bar "${score}" "${max_score}" "Header Coverage"
  echo ""

  local pct
  pct=$(( score * 100 / max_score )) || true

  [[ "${missing_critical}" -gt 0 ]] && \
    print_warning "${missing_critical} critical header(s) missing — immediate attention recommended"
  [[ "${missing_high}" -gt 0 ]] && \
    print_warning "${missing_high} high-severity header(s) missing"
  [[ "${missing_critical}" -eq 0 && "${missing_high}" -eq 0 && "${pct}" -lt 100 ]] && \
    print_info "No critical issues — review medium/low items above"
  [[ "${pct}" -eq 100 ]] && \
    print_success "Perfect score! All security headers are present."

  print_section_end
}
