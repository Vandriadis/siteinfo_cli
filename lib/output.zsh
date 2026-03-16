#!/usr/bin/env zsh
# output.zsh — Formatting helpers for terminal output
# All color/style constants and print functions live here.

# ---------------------------------------------------------------------------
# ANSI color codes
# ---------------------------------------------------------------------------
typeset -g CLR_RESET='\033[0m'
typeset -g CLR_BOLD='\033[1m'
typeset -g CLR_DIM='\033[2m'

typeset -g CLR_RED='\033[0;31m'
typeset -g CLR_GREEN='\033[0;32m'
typeset -g CLR_YELLOW='\033[0;33m'
typeset -g CLR_BLUE='\033[0;34m'
typeset -g CLR_MAGENTA='\033[0;35m'
typeset -g CLR_CYAN='\033[0;36m'
typeset -g CLR_WHITE='\033[0;37m'

typeset -g CLR_BOLD_RED='\033[1;31m'
typeset -g CLR_BOLD_GREEN='\033[1;32m'
typeset -g CLR_BOLD_YELLOW='\033[1;33m'
typeset -g CLR_BOLD_BLUE='\033[1;34m'
typeset -g CLR_BOLD_CYAN='\033[1;36m'
typeset -g CLR_BOLD_WHITE='\033[1;37m'

# Column width for key/value alignment
typeset -g KV_WIDTH=22

# ---------------------------------------------------------------------------
# print_banner — top-level app banner
# ---------------------------------------------------------------------------
print_banner() {
  echo ""
  printf "${CLR_BOLD_CYAN}%s${CLR_RESET}\n" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "${CLR_BOLD_WHITE}  SiteInfo — Website Analysis Tool${CLR_RESET}\n"
  printf "${CLR_DIM}  Powered by curl · dig · host${CLR_RESET}\n"
  printf "${CLR_BOLD_CYAN}%s${CLR_RESET}\n" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ---------------------------------------------------------------------------
# print_section — section header
# Usage: print_section "DNS Records"
# ---------------------------------------------------------------------------
print_section() {
  local title="${1}"
  echo ""
  printf "${CLR_BOLD_CYAN}┌─ ${CLR_BOLD_WHITE}%-40s${CLR_BOLD_CYAN} ─┐${CLR_RESET}\n" "${title}"
}

# ---------------------------------------------------------------------------
# print_section_end — close a section visually
# ---------------------------------------------------------------------------
print_section_end() {
  printf "${CLR_BOLD_CYAN}└────────────────────────────────────────────┘${CLR_RESET}\n"
  echo ""
}

# ---------------------------------------------------------------------------
# print_key_value — aligned key: value line
# Usage: print_key_value "Status" "200"
# Usage: print_key_value "Status" "200" "green"
# ---------------------------------------------------------------------------
print_key_value() {
  local key="${1}"
  local value="${2}"
  local color="${3:-white}"

  local value_clr
  case "${color}" in
    green)   value_clr="${CLR_GREEN}" ;;
    yellow)  value_clr="${CLR_YELLOW}" ;;
    red)     value_clr="${CLR_BOLD_RED}" ;;
    cyan)    value_clr="${CLR_CYAN}" ;;
    magenta) value_clr="${CLR_MAGENTA}" ;;
    *)       value_clr="${CLR_WHITE}" ;;
  esac

  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  ${value_clr}%s${CLR_RESET}\n" "${key}:" "${value}"
}

# ---------------------------------------------------------------------------
# print_list_item — indented bullet point
# Usage: print_list_item "some value"
# ---------------------------------------------------------------------------
print_list_item() {
  printf "  ${CLR_CYAN}▸${CLR_RESET}  %s\n" "${1}"
}

# ---------------------------------------------------------------------------
# print_success — green success message
# ---------------------------------------------------------------------------
print_success() {
  printf "  ${CLR_BOLD_GREEN}✔  %s${CLR_RESET}\n" "${1}"
}

# ---------------------------------------------------------------------------
# print_warning — yellow warning message
# ---------------------------------------------------------------------------
print_warning() {
  printf "  ${CLR_BOLD_YELLOW}⚠  %s${CLR_RESET}\n" "${1}"
}

# ---------------------------------------------------------------------------
# print_error — red error message
# ---------------------------------------------------------------------------
print_error() {
  printf "  ${CLR_BOLD_RED}✖  %s${CLR_RESET}\n" "${1}" >&2
}

# ---------------------------------------------------------------------------
# print_info — dim informational message
# ---------------------------------------------------------------------------
print_info() {
  printf "  ${CLR_DIM}ℹ  %s${CLR_RESET}\n" "${1}"
}

# ---------------------------------------------------------------------------
# print_separator — horizontal rule
# ---------------------------------------------------------------------------
print_separator() {
  printf "${CLR_DIM}%s${CLR_RESET}\n" "  ──────────────────────────────────────────"
}

# ---------------------------------------------------------------------------
# print_detected — technology detection hit
# Usage: print_detected "React" "meta[name=next-head-count]"
# ---------------------------------------------------------------------------
print_detected() {
  local tech="${1}"
  local pattern="${2}"
  printf "  ${CLR_BOLD_GREEN}[✔]${CLR_RESET} ${CLR_BOLD_WHITE}%-22s${CLR_RESET}  ${CLR_DIM}via: %s${CLR_RESET}\n" "${tech}" "${pattern}"
}

# ---------------------------------------------------------------------------
# print_not_detected — technology not found
# ---------------------------------------------------------------------------
print_not_detected() {
  local tech="${1}"
  printf "  ${CLR_DIM}[ ]  %-22s  not detected${CLR_RESET}\n" "${tech}"
}

# ---------------------------------------------------------------------------
# print_header_present — security header present (good)
# ---------------------------------------------------------------------------
print_header_present() {
  local header="${1}"
  local value="${2}"
  printf "  ${CLR_BOLD_GREEN}[✔]${CLR_RESET} ${CLR_BOLD_WHITE}%-32s${CLR_RESET}  ${CLR_GREEN}%s${CLR_RESET}\n" "${header}" "${value}"
}

# ---------------------------------------------------------------------------
# print_header_missing — security header absent (bad)
# ---------------------------------------------------------------------------
print_header_missing() {
  local header="${1}"
  printf "  ${CLR_BOLD_RED}[✖]${CLR_RESET} ${CLR_BOLD_WHITE}%-32s${CLR_RESET}  ${CLR_YELLOW}MISSING${CLR_RESET}\n" "${header}"
}

# ---------------------------------------------------------------------------
# print_comparison_row — side-by-side desktop vs mobile row
# Usage: print_comparison_row "Status" "200" "200"
# ---------------------------------------------------------------------------
print_comparison_row() {
  local label="${1}"
  local desktop="${2}"
  local mobile="${3}"
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  ${CLR_CYAN}%-30s${CLR_RESET}  ${CLR_MAGENTA}%s${CLR_RESET}\n" \
    "${label}:" "${desktop}" "${mobile}"
}
