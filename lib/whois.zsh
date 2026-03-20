#!/usr/bin/env zsh
# whois.zsh — WHOIS domain registration lookup module
# Queries whois for registrar, dates, status and name servers.
# Provides an expiry countdown with color-coded urgency.

# ---------------------------------------------------------------------------
# _whois_field — extract the first match of a case-insensitive label
# Usage: value=$(_whois_field "${raw}" "Registrar" "Registrant Organization")
#   Accepts multiple label patterns (tried in order, first non-empty wins)
# ---------------------------------------------------------------------------
_whois_field() {
  local raw="${1}"; shift
  local val=""
  for label in "$@"; do
    val=$(echo "${raw}" | grep -i "^${label}:" | head -1 \
      | cut -d: -f2- | sed 's/^ *//' | tr -d '\r\n')
    [[ -n "${val}" ]] && echo "${val}" && return
  done
  echo ""
}

# ---------------------------------------------------------------------------
# _whois_registrable — strip subdomains, return registrable domain
# e.g. www.sub.example.co.uk → example.co.uk  (best-effort, 2-part TLD)
# ---------------------------------------------------------------------------
_whois_registrable() {
  local host="${1}"
  # Known two-part TLDs
  if [[ "${host}" =~ \.(co|com|net|org|gov|edu|ac|me|ltd)\.[a-z]{2}$ ]]; then
    echo "${host}" | awk -F. '{print $(NF-2)"."$(NF-1)"."$NF}'
  else
    echo "${host}" | awk -F. '{print $(NF-1)"."$NF}'
  fi
}

# ---------------------------------------------------------------------------
# _whois_expiry_status — print expiry countdown with color urgency
# Usage: _whois_expiry_status "2026-08-15T00:00:00Z"
# ---------------------------------------------------------------------------
_whois_expiry_status() {
  local expiry_raw="${1}"

  # Extract ISO date YYYY-MM-DD
  local expiry_iso
  expiry_iso=$(echo "${expiry_raw}" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  [[ -z "${expiry_iso}" ]] && return

  local now_epoch expiry_epoch
  now_epoch=$(date +%s)
  # macOS date -j -f for parsing
  expiry_epoch=$(date -j -f "%Y-%m-%d" "${expiry_iso}" "+%s" 2>/dev/null)
  [[ -z "${expiry_epoch}" ]] && return

  local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

  if (( days_left < 0 )); then
    printf "  ${CLR_BOLD_RED}✖  Domain EXPIRED %d days ago!${CLR_RESET}\n" "${days_left#-}"
  elif (( days_left <= 30 )); then
    printf "  ${CLR_BOLD_RED}⚠  Expires in %d days — renew immediately!${CLR_RESET}\n" "${days_left}"
  elif (( days_left <= 90 )); then
    printf "  ${CLR_BOLD_YELLOW}⚠  Expires in %d days${CLR_RESET}\n" "${days_left}"
  else
    printf "  ${CLR_BOLD_GREEN}✔  Expires in %d days${CLR_RESET}\n" "${days_left}"
  fi
}

# ---------------------------------------------------------------------------
# run_whois — main WHOIS analysis function
# Usage: run_whois "https://example.com"
# ---------------------------------------------------------------------------
run_whois() {
  local url="${1}"
  local host
  host=$(extract_host "${url}")

  if [[ -z "${host}" ]]; then
    print_error "Could not extract domain from URL: ${url}"
    return 1
  fi

  local domain
  domain=$(_whois_registrable "${host}")

  print_section "WHOIS — ${domain}"

  # ── Dependency check ─────────────────────────────────────────────────────
  if ! command -v whois &>/dev/null; then
    print_error "whois not found.  Install with: brew install whois"
    print_section_end
    return 1
  fi

  print_info "Querying WHOIS for ${domain}..."

  local raw
  raw=$(whois "${domain}" 2>/dev/null)

  if [[ -z "${raw}" ]]; then
    print_error "No WHOIS data returned for ${domain}"
    print_section_end
    return 1
  fi

  # ── Domain not found ──────────────────────────────────────────────────────
  if echo "${raw}" | grep -qiE \
    "No match|NOT FOUND|No entries found|Object does not exist|Domain not found|^%.*not found"; then
    print_warning "Domain ${domain} not found in WHOIS"
    print_section_end
    return 0
  fi

  # ── Parse fields ──────────────────────────────────────────────────────────
  local registrar creation_date expiry_date updated_date domain_status

  registrar=$(_whois_field "${raw}" \
    "Registrar" "Registrar Name" "sponsoring registrar" "Registrant Organization")

  creation_date=$(_whois_field "${raw}" \
    "Creation Date" "Created" "created" "Domain registered" "Registered on" \
    "Registration Date" "domain registered" "Registration Time")

  expiry_date=$(_whois_field "${raw}" \
    "Registry Expiry Date" "Registrar Registration Expiration Date" \
    "Expiry Date" "Expiration Date" "Expiry date" "paid-till" \
    "Expires on" "Renewal date" "Domain expires")

  updated_date=$(_whois_field "${raw}" \
    "Updated Date" "Last Modified" "last-update" "Modified" \
    "Last updated" "Last Update")

  domain_status=$(_whois_field "${raw}" \
    "Domain Status" "Status" "state")

  # ── Name servers ──────────────────────────────────────────────────────────
  local nameservers
  nameservers=$(echo "${raw}" \
    | grep -iE "^Name Server:|^nserver:" \
    | grep -v "#" \
    | cut -d: -f2- \
    | awk '{print $1}' \
    | tr '[:upper:]' '[:lower:]' \
    | tr -d '\r' \
    | grep -v "gtld-servers\.net$" \
    | sort -u)

  # ── Registration Info ─────────────────────────────────────────────────────
  print_separator
  print_subheader "Registration Info"

  print_key_value "Domain"       "${domain}"       "cyan"
  [[ -n "${registrar}" ]]     && print_key_value "Registrar"    "${registrar}"     "white"
  [[ -n "${creation_date}" ]] && print_key_value "Created"      "${creation_date}" "white"
  [[ -n "${expiry_date}" ]]   && print_key_value "Expires"      "${expiry_date}"   "yellow"
  [[ -n "${updated_date}" ]]  && print_key_value "Last Updated" "${updated_date}"  "white"

  # Trim status to first part (avoid very long ICANN URL suffixes)
  if [[ -n "${domain_status}" ]]; then
    local short_status
    short_status=$(echo "${domain_status}" | awk '{print $1}')
    print_key_value "Status" "${short_status}" "white"
  fi

  # ── Name Servers ──────────────────────────────────────────────────────────
  if [[ -n "${nameservers}" ]]; then
    local ns_count
    ns_count=$(echo "${nameservers}" | grep -c '[^[:space:]]')
    print_separator
    print_subheader "Name Servers" "${ns_count}"
    while IFS= read -r ns; do
      [[ -z "${ns// }" ]] && continue
      print_list_item "${ns}"
    done <<< "${nameservers}"
  fi

  # ── Expiry countdown ──────────────────────────────────────────────────────
  if [[ -n "${expiry_date}" ]]; then
    print_separator
    _whois_expiry_status "${expiry_date}"
  fi

  # ── Summary ───────────────────────────────────────────────────────────────
  print_separator
  echo ""
  print_key_value "Domain"     "${domain}"    "cyan"
  [[ -n "${registrar}" ]] && print_key_value "Registrar" "${registrar}" "white"

  print_section_end
}
