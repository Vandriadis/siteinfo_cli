#!/usr/bin/env zsh
# dns.zsh — DNS record lookup module
# Uses dig and host to collect A, AAAA, CNAME, NS, MX, TXT records.

# ---------------------------------------------------------------------------
# _dns_query — run a dig query for a specific record type
# Usage: _dns_query "example.com" "A"
# Returns newline-separated answer values, empty string on failure
# ---------------------------------------------------------------------------
_dns_query() {
  local domain="${1}"
  local rtype="${2}"
  local timeout=5

  dig +short +time="${timeout}" +tries=2 "${rtype}" "${domain}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _host_query — use host as a fallback resolver
# Usage: _host_query "example.com"
# ---------------------------------------------------------------------------
_host_query() {
  local domain="${1}"
  host -W 5 "${domain}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _dns_print_records — print a record group with section label
# Usage: _dns_print_records "A Records" "${a_records}"
# ---------------------------------------------------------------------------
_dns_print_records() {
  local label="${1}"
  local records="${2}"

  if [[ -n "${records}" ]]; then
    print_separator
    printf "  ${CLR_BOLD_YELLOW}%-16s${CLR_RESET}\n" "${label}"
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      print_list_item "${line}"
    done <<< "${records}"
  else
    print_separator
    printf "  ${CLR_BOLD_YELLOW}%-16s${CLR_RESET}  ${CLR_DIM}(none)${CLR_RESET}\n" "${label}"
  fi
}

# ---------------------------------------------------------------------------
# run_dns — main DNS analysis function
# Usage: run_dns "https://example.com"
# ---------------------------------------------------------------------------
run_dns() {
  local url="${1}"
  local domain
  domain=$(extract_host "${url}")

  if [[ -z "${domain}" ]]; then
    print_error "Could not extract domain from URL: ${url}"
    return 1
  fi

  print_section "DNS Information — ${domain}"

  # ── A Records ────────────────────────────────────────────────────────────
  local a_records
  a_records=$(_dns_query "${domain}" "A")
  _dns_print_records "A Records (IPv4)" "${a_records}"

  # ── AAAA Records ─────────────────────────────────────────────────────────
  local aaaa_records
  aaaa_records=$(_dns_query "${domain}" "AAAA")
  _dns_print_records "AAAA Records (IPv6)" "${aaaa_records}"

  # ── CNAME Records ────────────────────────────────────────────────────────
  local cname_records
  cname_records=$(_dns_query "${domain}" "CNAME")
  _dns_print_records "CNAME Records" "${cname_records}"

  # ── NS Records ───────────────────────────────────────────────────────────
  local ns_records
  ns_records=$(_dns_query "${domain}" "NS")
  _dns_print_records "NS Records" "${ns_records}"

  # ── MX Records ───────────────────────────────────────────────────────────
  local mx_records
  mx_records=$(_dns_query "${domain}" "MX")
  _dns_print_records "MX Records" "${mx_records}"

  # ── TXT Records ──────────────────────────────────────────────────────────
  local txt_records
  txt_records=$(_dns_query "${domain}" "TXT")
  _dns_print_records "TXT Records" "${txt_records}"

  # ── SOA Record ───────────────────────────────────────────────────────────
  local soa_record
  soa_record=$(dig +short SOA "${domain}" 2>/dev/null | head -1)
  if [[ -n "${soa_record}" ]]; then
    print_separator
    printf "  ${CLR_BOLD_YELLOW}%-16s${CLR_RESET}\n" "SOA Record"
    print_list_item "${soa_record}"
  fi

  # ── Reverse DNS (PTR) for first A record ─────────────────────────────────
  local first_ip
  first_ip=$(echo "${a_records}" | head -1)
  if [[ -n "${first_ip}" ]]; then
    local ptr_record
    ptr_record=$(dig +short PTR "${first_ip}" 2>/dev/null | head -1)
    if [[ -n "${ptr_record}" ]]; then
      print_separator
      printf "  ${CLR_BOLD_YELLOW}%-16s${CLR_RESET}\n" "Reverse DNS (PTR)"
      print_list_item "${first_ip} → ${ptr_record}"
    fi
  fi

  # ── Summary ──────────────────────────────────────────────────────────────
  print_separator
  echo ""
  local ip_count
  ip_count=$(echo "${a_records}" | grep -c . 2>/dev/null || echo 0)
  local ipv6_count
  ipv6_count=$(echo "${aaaa_records}" | grep -c . 2>/dev/null || echo 0)

  print_key_value "Domain" "${domain}" "cyan"
  print_key_value "IPv4 Addresses" "${ip_count}" "white"
  print_key_value "IPv6 Addresses" "${ipv6_count}" "white"

  print_section_end
}
