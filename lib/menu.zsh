#!/usr/bin/env zsh
# menu.zsh — Interactive menu system
# Handles display, user input routing, and the main event loop.

# User-agent strings used across modules
typeset -g UA_DESKTOP='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
typeset -g UA_MOBILE='Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'

# ---------------------------------------------------------------------------
# show_menu — display the main navigation menu
# ---------------------------------------------------------------------------
show_menu() {
  print_banner
  printf "  ${CLR_BOLD_WHITE}What would you like to do?${CLR_RESET}\n\n"

  printf "  ${CLR_BOLD_CYAN} 1)${CLR_RESET}  ${CLR_WHITE}Full site scan${CLR_RESET}           ${CLR_DIM}DNS + HTTP + Tech + Security${CLR_RESET}\n"
  printf "  ${CLR_BOLD_CYAN} 2)${CLR_RESET}  ${CLR_WHITE}DNS information${CLR_RESET}          ${CLR_DIM}A, AAAA, NS, MX, TXT records${CLR_RESET}\n"
  printf "  ${CLR_BOLD_CYAN} 3)${CLR_RESET}  ${CLR_WHITE}HTTP response info${CLR_RESET}       ${CLR_DIM}Status, headers, redirects, timing${CLR_RESET}\n"
  printf "  ${CLR_BOLD_CYAN} 4)${CLR_RESET}  ${CLR_WHITE}Detect technologies${CLR_RESET}      ${CLR_DIM}Frameworks, CMS, analytics, CDN${CLR_RESET}\n"
  printf "  ${CLR_BOLD_CYAN} 5)${CLR_RESET}  ${CLR_WHITE}Security headers${CLR_RESET}         ${CLR_DIM}CSP, HSTS, X-Frame-Options, cookies${CLR_RESET}\n"
  printf "  ${CLR_BOLD_CYAN} 6)${CLR_RESET}  ${CLR_WHITE}Desktop vs Mobile${CLR_RESET}        ${CLR_DIM}Compare responses across user agents${CLR_RESET}\n"
  printf "  ${CLR_BOLD_CYAN} 7)${CLR_RESET}  ${CLR_WHITE}WHOIS lookup${CLR_RESET}             ${CLR_DIM}Registrar, dates, expiry countdown${CLR_RESET}\n"
  printf "  ${CLR_BOLD_CYAN} 8)${CLR_RESET}  ${CLR_WHITE}Exit${CLR_RESET}\n"
  echo ""
  printf "${CLR_BOLD_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CLR_RESET}\n"
  printf "  ${CLR_BOLD_WHITE}Choose an option ${CLR_DIM}[1-8]${CLR_RESET}${CLR_BOLD_WHITE}:${CLR_RESET} "
}

# ---------------------------------------------------------------------------
# run_full_scan — run all four analysis modules on a single URL
# ---------------------------------------------------------------------------
run_full_scan() {
  local url="${1}"

  echo ""
  printf "${CLR_BOLD_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CLR_RESET}\n"
  printf "  ${CLR_BOLD_WHITE}Full Site Scan — %s${CLR_RESET}\n" "${url}"
  printf "${CLR_BOLD_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CLR_RESET}\n"

  run_dns      "${url}"
  run_http     "${url}"
  run_detect   "${url}"
  run_security "${url}"
  run_whois    "${url}"
}

# ---------------------------------------------------------------------------
# run_compare — desktop vs mobile comparison
# Usage: run_compare "https://example.com"
# ---------------------------------------------------------------------------
run_compare() {
  local url="${1}"

  print_section "Desktop vs Mobile Comparison — ${url}"

  # ── Desktop request ───────────────────────────────────────────────────────
  print_info "Fetching desktop response..."
  local desktop_raw
  desktop_raw=$(curl --silent --head --max-time 15 --connect-timeout 8 \
    --location --max-redirs 10 \
    --user-agent "${UA_DESKTOP}" \
    --write-out '\n%{http_code}|%{url_effective}|%{size_download}|%{num_redirects}|%{time_total}' \
    "${url}" 2>/dev/null)

  local desktop_meta
  desktop_meta=$(echo "${desktop_raw}" | tail -1)
  local desktop_headers
  desktop_headers=$(echo "${desktop_raw}" | sed '$d')

  local d_code d_url d_size d_redir d_time
  IFS='|' read -r d_code d_url d_size d_redir d_time <<< "${desktop_meta}"

  # ── Mobile request ────────────────────────────────────────────────────────
  print_info "Fetching mobile response..."
  local mobile_raw
  mobile_raw=$(curl --silent --head --max-time 15 --connect-timeout 8 \
    --location --max-redirs 10 \
    --user-agent "${UA_MOBILE}" \
    --write-out '\n%{http_code}|%{url_effective}|%{size_download}|%{num_redirects}|%{time_total}' \
    "${url}" 2>/dev/null)

  local mobile_meta
  mobile_meta=$(echo "${mobile_raw}" | tail -1)
  local mobile_headers
  mobile_headers=$(echo "${mobile_raw}" | sed '$d')

  local m_code m_url m_size m_redir m_time
  IFS='|' read -r m_code m_url m_size m_redir m_time <<< "${mobile_meta}"

  if [[ -z "${d_code}" || -z "${m_code}" ]]; then
    print_error "Failed to fetch one or both responses from ${url}"
    print_section_end
    return 1
  fi

  # ── Side-by-side comparison table ─────────────────────────────────────────
  print_separator
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  ${CLR_BOLD_CYAN}%-30s${CLR_RESET}  ${CLR_BOLD_MAGENTA}%s${CLR_RESET}\n" \
    "" "DESKTOP" "MOBILE"
  print_separator

  # Status — resolve color names to ANSI codes via case
  local d_sc_clr m_sc_clr _d_ansi _m_ansi
  d_sc_clr=$(status_color "${d_code}")
  m_sc_clr=$(status_color "${m_code}")
  case "${d_sc_clr}" in
    green)   _d_ansi="${CLR_GREEN}"    ;;
    yellow)  _d_ansi="${CLR_YELLOW}"   ;;
    red)     _d_ansi="${CLR_BOLD_RED}" ;;
    *)       _d_ansi="${CLR_WHITE}"    ;;
  esac
  case "${m_sc_clr}" in
    green)   _m_ansi="${CLR_GREEN}"    ;;
    yellow)  _m_ansi="${CLR_YELLOW}"   ;;
    red)     _m_ansi="${CLR_BOLD_RED}" ;;
    *)       _m_ansi="${CLR_WHITE}"    ;;
  esac
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  " "Status Code:"
  printf "${_d_ansi}%-30s${CLR_RESET}  " "${d_code}"
  printf "${_m_ansi}%s${CLR_RESET}\n" "${m_code}"

  # Final URL
  print_comparison_row "Final URL" "${d_url:0:35}" "${m_url:0:35}"

  # Redirects
  print_comparison_row "Redirect Hops" "${d_redir:-0}" "${m_redir:-0}"

  # Total time
  print_comparison_row "Total Time" "${d_time}s" "${m_time}s"

  # ── Specific header comparison ─────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Header Differences${CLR_RESET}\n"
  echo ""

  local important_headers=(
    "server"
    "content-type"
    "vary"
    "cache-control"
    "x-frame-options"
    "strict-transport-security"
  )

  local found_diff=0
  local _hdr _d_val _m_val
  for _hdr in "${important_headers[@]}"; do
    _d_val=$(echo "${desktop_headers}" | grep -i "^${_hdr}:" | tail -1 | cut -d: -f2- | sed 's/^ *//' | tr -d '\r')
    _m_val=$(echo "${mobile_headers}"  | grep -i "^${_hdr}:" | tail -1 | cut -d: -f2- | sed 's/^ *//' | tr -d '\r')

    if [[ "${_d_val}" != "${_m_val}" ]]; then
      printf "  ${CLR_BOLD_YELLOW}%-28s${CLR_RESET}\n" "$(echo "${_hdr}" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')"
      printf "    ${CLR_CYAN}Desktop:${CLR_RESET} %s\n" "${_d_val:-(not set)}"
      printf "    ${CLR_MAGENTA}Mobile: ${CLR_RESET} %s\n" "${_m_val:-(not set)}"
      echo ""
      found_diff=1
    fi
  done

  if (( found_diff == 0 )); then
    print_info "No differences found in key headers between desktop and mobile"
  fi

  # ── URL difference check ──────────────────────────────────────────────────
  print_separator
  if [[ "${d_url}" != "${m_url}" ]]; then
    print_warning "Different final URLs detected!"
    print_key_value "Desktop URL" "${d_url}" "cyan"
    print_key_value "Mobile URL"  "${m_url}" "magenta"
    print_info "Site may serve separate mobile version (m.example.com)"
  else
    print_success "Same final URL for desktop and mobile"
  fi

  # ── Vary header analysis ───────────────────────────────────────────────────
  local d_vary
  d_vary=$(echo "${desktop_headers}" | grep -i "^vary:" | tr -d '\r' | cut -d: -f2- | sed 's/^ *//')
  if echo "${d_vary}" | grep -qi "user-agent"; then
    print_warning "Vary: User-Agent detected — server serves different content per device"
  fi

  print_section_end
}

# ---------------------------------------------------------------------------
# menu_loop — main interactive event loop
# ---------------------------------------------------------------------------
menu_loop() {
  local choice url

  while true; do
    show_menu
    read -r choice

    case "${choice}" in
      1|2|3|4|5|6|7)
        # All options except exit require a URL
        echo ""
        if ! prompt_url; then
          pause
          continue
        fi
        url="${CURRENT_URL}"

        case "${choice}" in
          1) run_full_scan  "${url}" ;;
          2) run_dns        "${url}" ;;
          3) run_http       "${url}" ;;
          4) run_detect     "${url}" ;;
          5) run_security   "${url}" ;;
          6) run_compare    "${url}" ;;
          7) run_whois      "${url}" ;;
        esac

        pause
        ;;

      8|q|Q|exit|quit)
        echo ""
        printf "  ${CLR_BOLD_CYAN}Goodbye!${CLR_RESET}\n\n"
        exit 0
        ;;

      "")
        # User just pressed Enter — show menu again
        ;;

      *)
        echo ""
        print_warning "Invalid option '${choice}'. Please choose 1–8."
        sleep 1
        ;;
    esac
  done
}
