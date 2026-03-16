#!/usr/bin/env zsh
# dns.zsh — DNS record lookup module
# Uses dig and host to collect A, AAAA, CNAME, NS, MX, TXT records.

# ---------------------------------------------------------------------------
# _dns_query — run a dig query for a specific record type
# Returns newline-separated answer values, empty string on failure
# ---------------------------------------------------------------------------
_dns_query() {
  local domain="${1}"
  local rtype="${2}"
  dig +short +time=5 +tries=2 "${rtype}" "${domain}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _dns_count — count non-empty lines in a record string
# ---------------------------------------------------------------------------
_dns_count() {
  local records="${1}"
  [[ -z "${records}" ]] && echo 0 && return
  echo "${records}" | grep -c '[^[:space:]]' 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# _dns_print_records — print a record group; silently skips if empty
# Usage: _dns_print_records "A Records" "${records}" [always_show]
#   always_show = 1 forces printing even when empty (used for A/AAAA)
# ---------------------------------------------------------------------------
_dns_print_records() {
  local label="${1}"
  local records="${2}"
  local always_show="${3:-0}"

  local count
  count=$(_dns_count "${records}")

  # Skip empty optional record types
  if [[ "${count}" -eq 0 && "${always_show}" -eq 0 ]]; then
    return
  fi

  print_separator
  print_subheader "${label}" "${count}"

  if [[ "${count}" -eq 0 ]]; then
    printf "  ${CLR_DIM}  (none)${CLR_RESET}\n"
  else
    while IFS= read -r line; do
      [[ -z "${line// }" ]] && continue
      print_list_item "${line}"
    done <<< "${records}"
  fi
}

# ---------------------------------------------------------------------------
# _detect_cdn_from_ip — identify known CDN/hosting providers by IP prefix
# Usage: provider=$(_detect_cdn_from_ip "104.18.26.120")
# ---------------------------------------------------------------------------
_detect_cdn_from_ip() {
  local ip="${1}"
  case "${ip}" in
    104.16.*|104.17.*|104.18.*|104.19.*|104.20.*|104.21.*|\
    104.22.*|104.23.*|104.24.*|104.25.*|104.26.*|104.27.*|\
    104.28.*|104.29.*|104.30.*|104.31.*|\
    172.64.*|172.65.*|172.66.*|172.67.*|172.68.*|172.69.*|\
    172.70.*|172.71.*|190.93.*|198.41.128.*|198.41.129.*|\
    198.41.192.*|198.41.193.*|162.159.*)
      echo "Cloudflare" ;;
    151.101.*|199.232.*|23.235.*)
      echo "Fastly" ;;
    13.*|52.*|54.*|3.*)
      echo "AWS" ;;
    34.*|35.*|130.211.*|146.148.*)
      echo "Google Cloud" ;;
    20.*|40.*|52.239.*|52.240.*)
      echo "Azure" ;;
    185.31.16.*|185.31.17.*|185.31.18.*|185.31.19.*)
      echo "GitHub Pages" ;;
    76.76.21.*|76.76.19.*)
      echo "Vercel" ;;
    75.2.*|99.83.*)
      echo "AWS Global Accelerator" ;;
    *)
      echo "" ;;
  esac
}

# ---------------------------------------------------------------------------
# _print_a_records — print A records with optional CDN hints
# ---------------------------------------------------------------------------
_print_a_records() {
  local records="${1}"
  local count
  count=$(_dns_count "${records}")

  print_separator
  print_subheader "A Records  (IPv4)" "${count}"

  if [[ "${count}" -eq 0 ]]; then
    printf "  ${CLR_DIM}  (none)${CLR_RESET}\n"
    return
  fi

  while IFS= read -r ip; do
    [[ -z "${ip// }" ]] && continue
    local cdn
    cdn=$(_detect_cdn_from_ip "${ip}")
    if [[ -n "${cdn}" ]]; then
      printf "  ${CLR_CYAN}▸${CLR_RESET}  %-20s  ${CLR_DIM}← %s${CLR_RESET}\n" "${ip}" "${cdn}"
    else
      print_list_item "${ip}"
    fi
  done <<< "${records}"
}

# ---------------------------------------------------------------------------
# _print_mx_records — print MX records with priority highlighted
# ---------------------------------------------------------------------------
_print_mx_records() {
  local records="${1}"
  local count
  count=$(_dns_count "${records}")

  [[ "${count}" -eq 0 ]] && return

  print_separator
  print_subheader "MX Records  (mail)" "${count}"

  # Declare loop vars before the loop to avoid zsh printing re-declared locals
  local _mx_pri _mx_host _mx_line
  while IFS= read -r _mx_line; do
    [[ -z "${_mx_line// }" ]] && continue
    _mx_pri=$(echo "${_mx_line}" | awk '{print $1}')
    _mx_host=$(echo "${_mx_line}" | awk '{print $2}')
    printf "  ${CLR_CYAN}▸${CLR_RESET}  ${CLR_DIM}pri %-4s${CLR_RESET}  %s\n" "${_mx_pri}" "${_mx_host:-${_mx_line}}"
  done <<< "${records}"
}

# ---------------------------------------------------------------------------
# _print_txt_records — print TXT records, flagging SPF/DKIM/DMARC entries
# ---------------------------------------------------------------------------
_print_txt_records() {
  local records="${1}"
  local count
  count=$(_dns_count "${records}")

  [[ "${count}" -eq 0 ]] && return

  print_separator
  print_subheader "TXT Records" "${count}"

  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    local tag=""
    case "${line}" in
      *"v=spf1"*)     tag="${CLR_CYAN}[SPF]${CLR_RESET} " ;;
      *"v=DMARC1"*)   tag="${CLR_CYAN}[DMARC]${CLR_RESET} " ;;
      *"v=DKIM1"*)    tag="${CLR_CYAN}[DKIM]${CLR_RESET} " ;;
      *"v=TLSRPTv1"*) tag="${CLR_CYAN}[TLSRPT]${CLR_RESET} " ;;
      *"google-site"*) tag="${CLR_DIM}[Google]${CLR_RESET} " ;;
    esac
    printf "  ${CLR_CYAN}▸${CLR_RESET}  %b%s\n" "${tag}" "${line}"
  done <<< "${records}"
}

# ---------------------------------------------------------------------------
# _print_soa — parse and display SOA fields in a readable layout
# ---------------------------------------------------------------------------
_print_soa() {
  local record="${1}"
  [[ -z "${record}" ]] && return

  print_separator
  print_subheader "SOA Record"

  local primary_ns admin serial refresh retry expire ttl
  read -r primary_ns admin serial refresh retry expire ttl <<< "${record}"

  printf "  ${CLR_CYAN}▸${CLR_RESET}  ${CLR_DIM}Primary NS:${CLR_RESET}  %s\n" "${primary_ns}"
  printf "  ${CLR_CYAN}▸${CLR_RESET}  ${CLR_DIM}Admin:     ${CLR_RESET}  %s\n" "${admin}"
  printf "  ${CLR_CYAN}▸${CLR_RESET}  ${CLR_DIM}Serial:    ${CLR_RESET}  %s\n" "${serial}"
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

  # ── A Records (always shown, with CDN hints) ──────────────────────────────
  local a_records
  a_records=$(_dns_query "${domain}" "A")
  _print_a_records "${a_records}"

  # ── AAAA Records (always shown) ───────────────────────────────────────────
  local aaaa_records
  aaaa_records=$(_dns_query "${domain}" "AAAA")
  _dns_print_records "AAAA Records  (IPv6)" "${aaaa_records}" 1

  # ── CNAME Records (only if present) ───────────────────────────────────────
  local cname_records
  cname_records=$(_dns_query "${domain}" "CNAME")
  _dns_print_records "CNAME Records" "${cname_records}"

  # ── NS Records ────────────────────────────────────────────────────────────
  local ns_records
  ns_records=$(_dns_query "${domain}" "NS")
  _dns_print_records "NS Records" "${ns_records}"

  # ── MX Records (formatted with priority) ─────────────────────────────────
  local mx_records
  mx_records=$(_dns_query "${domain}" "MX")
  _print_mx_records "${mx_records}"

  # ── TXT Records (with tag detection) ─────────────────────────────────────
  local txt_records
  txt_records=$(_dns_query "${domain}" "TXT")
  _print_txt_records "${txt_records}"

  # ── SOA Record (parsed) ───────────────────────────────────────────────────
  local soa_record
  soa_record=$(dig +short SOA "${domain}" 2>/dev/null | head -1)
  _print_soa "${soa_record}"

  # ── Reverse DNS (PTR) for first A record ──────────────────────────────────
  local first_ip
  first_ip=$(echo "${a_records}" | head -1)
  if [[ -n "${first_ip}" ]]; then
    local ptr_record
    ptr_record=$(dig +short PTR "${first_ip}" 2>/dev/null | head -1)
    if [[ -n "${ptr_record}" ]]; then
      print_separator
      print_subheader "Reverse DNS  (PTR)"
      printf "  ${CLR_CYAN}▸${CLR_RESET}  %s  ${CLR_DIM}→${CLR_RESET}  %s\n" "${first_ip}" "${ptr_record}"
    fi
  fi

  # ── Summary ───────────────────────────────────────────────────────────────
  print_separator
  echo ""
  local ip_count ipv6_count
  ip_count=$(_dns_count "${a_records}")
  ipv6_count=$(_dns_count "${aaaa_records}")

  print_key_value "Domain"         "${domain}"    "cyan"
  print_key_value "IPv4 Addresses" "${ip_count}"  "white"
  print_key_value "IPv6 Addresses" "${ipv6_count}" "white"

  # Show CDN if detected from first A record
  if [[ -n "${first_ip}" ]]; then
    local cdn
    cdn=$(_detect_cdn_from_ip "${first_ip}")
    [[ -n "${cdn}" ]] && print_key_value "CDN / Host"  "${cdn}" "magenta"
  fi

  # Note if SPF is configured
  if echo "${txt_records}" | grep -q "v=spf1"; then
    print_key_value "Email Auth"  "SPF configured" "green"
  fi
  if echo "${txt_records}" | grep -q "v=DMARC1"; then
    print_key_value "DMARC" "configured" "green"
  fi

  print_section_end
}
