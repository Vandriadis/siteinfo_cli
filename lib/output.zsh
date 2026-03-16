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
    bold)    value_clr="${CLR_BOLD_WHITE}" ;;
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
# print_subheader — yellow subsection label with optional count badge
# Usage: print_subheader "A Records" 3
# Usage: print_subheader "CNAME Records"
# ---------------------------------------------------------------------------
print_subheader() {
  local label="${1}"
  local count="${2:-}"

  if [[ -n "${count}" && "${count}" -gt 0 ]]; then
    printf "  ${CLR_BOLD_YELLOW}%s${CLR_RESET}  ${CLR_DIM}(%d)${CLR_RESET}\n" "${label}" "${count}"
  else
    printf "  ${CLR_BOLD_YELLOW}%s${CLR_RESET}\n" "${label}"
  fi
}

# ---------------------------------------------------------------------------
# http_status_text — map HTTP status code to reason phrase
# Usage: text=$(http_status_text 200)  →  "OK"
# ---------------------------------------------------------------------------
http_status_text() {
  case "${1}" in
    100) echo "Continue" ;;
    101) echo "Switching Protocols" ;;
    200) echo "OK" ;;
    201) echo "Created" ;;
    204) echo "No Content" ;;
    206) echo "Partial Content" ;;
    301) echo "Moved Permanently" ;;
    302) echo "Found" ;;
    303) echo "See Other" ;;
    304) echo "Not Modified" ;;
    307) echo "Temporary Redirect" ;;
    308) echo "Permanent Redirect" ;;
    400) echo "Bad Request" ;;
    401) echo "Unauthorized" ;;
    403) echo "Forbidden" ;;
    404) echo "Not Found" ;;
    405) echo "Method Not Allowed" ;;
    408) echo "Request Timeout" ;;
    410) echo "Gone" ;;
    422) echo "Unprocessable Entity" ;;
    429) echo "Too Many Requests" ;;
    500) echo "Internal Server Error" ;;
    501) echo "Not Implemented" ;;
    502) echo "Bad Gateway" ;;
    503) echo "Service Unavailable" ;;
    504) echo "Gateway Timeout" ;;
    *)   echo "" ;;
  esac
}

# ---------------------------------------------------------------------------
# print_status_line — formatted HTTP status with reason phrase and badge
# Usage: print_status_line 200
# ---------------------------------------------------------------------------
print_status_line() {
  local code="${1}"
  local text
  text=$(http_status_text "${code}")
  local label="${code}${text:+ ${text}}"

  local clr badge
  case "${code}" in
    2*) clr="${CLR_BOLD_GREEN}"; badge="●" ;;
    3*) clr="${CLR_BOLD_YELLOW}"; badge="●" ;;
    4*) clr="${CLR_BOLD_RED}"; badge="●" ;;
    5*) clr="${CLR_BOLD_RED}"; badge="●" ;;
    *)  clr="${CLR_WHITE}"; badge="●" ;;
  esac

  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  ${clr}%s %s${CLR_RESET}\n" \
    "Status:" "${badge}" "${label}"
}

# ---------------------------------------------------------------------------
# print_timing_row — timing metric with mini bar and speed color
# Usage: print_timing_row "DNS Lookup" "0.002" "0.500"
#   arg3 = threshold in seconds above which color turns yellow/red
# ---------------------------------------------------------------------------
print_timing_row() {
  local label="${1}"
  local value="${2}"   # seconds as float string e.g. "0.045"
  local warn="${3:-1}" # threshold for yellow
  local crit="${4:-3}" # threshold for red

  # Convert float seconds → ms integer for bar calculation
  local ms
  ms=$(printf '%.0f' "$(echo "${value} * 1000" | bc 2>/dev/null || echo 0)")

  # Color based on thresholds
  local clr
  local warn_ms crit_ms
  warn_ms=$(printf '%.0f' "$(echo "${warn} * 1000" | bc 2>/dev/null || echo 1000)")
  crit_ms=$(printf '%.0f' "$(echo "${crit} * 1000" | bc 2>/dev/null || echo 3000)")

  if   (( ms >= crit_ms )); then clr="${CLR_BOLD_RED}"
  elif (( ms >= warn_ms )); then clr="${CLR_YELLOW}"
  else                           clr="${CLR_GREEN}"
  fi

  # Mini bar: scale to 10 chars, max = 2000ms
  local bar_max=2000
  local bar_len=10
  local filled=$(( ms * bar_len / bar_max ))
  (( filled > bar_len )) && filled=${bar_len}
  local empty=$(( bar_len - filled ))

  local bar=""
  local i=0
  while (( i < filled )); do bar+="█"; (( i++ )); done
  i=0
  while (( i < empty ));  do bar+="░"; (( i++ )); done

  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  ${clr}%-10s${CLR_RESET}  ${CLR_DIM}%s${CLR_RESET}  ${CLR_DIM}%ss${CLR_RESET}\n" \
    "${label}:" "${bar}" "${ms}ms" "${value}"
}

# ---------------------------------------------------------------------------
# print_progress_bar — visual percentage bar
# Usage: print_progress_bar 75 100 "Security Score"
# ---------------------------------------------------------------------------
print_progress_bar() {
  local current="${1}"
  local total="${2}"
  local label="${3:-Score}"
  local bar_len=20

  local pct=$(( current * 100 / total ))
  local filled=$(( current * bar_len / total ))
  local empty=$(( bar_len - filled ))

  local clr grade
  if   (( pct >= 90 )); then clr="${CLR_BOLD_GREEN}";   grade="A"
  elif (( pct >= 75 )); then clr="${CLR_GREEN}";         grade="B"
  elif (( pct >= 50 )); then clr="${CLR_BOLD_YELLOW}";   grade="C"
  elif (( pct >= 25 )); then clr="${CLR_YELLOW}";        grade="D"
  else                       clr="${CLR_BOLD_RED}";      grade="F"
  fi

  local bar=""
  local i=0
  while (( i < filled )); do bar+="█"; (( i++ )); done
  i=0
  while (( i < empty ));  do bar+="░"; (( i++ )); done

  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  ${clr}%s${CLR_RESET}  ${clr}%3d%%${CLR_RESET}  ${CLR_DIM}Grade:${CLR_RESET} ${clr}%s${CLR_RESET}\n" \
    "${label}:" "${bar}" "${pct}" "${grade}"
}

# ---------------------------------------------------------------------------
# decode_html_entities — convert common HTML entities to plain text
# Usage: clean=$(decode_html_entities "Hello &amp; World &#8211; done")
# ---------------------------------------------------------------------------
decode_html_entities() {
  local s="${1}"
  s="${s//&amp;/&}"
  s="${s//&lt;/<}"
  s="${s//&gt;/>}"
  s="${s//&quot;/\"}"
  s="${s//&#039;/\'}"
  s="${s//&apos;/\'}"
  s="${s//&#8211;/–}"
  s="${s//&#8212;/—}"
  s="${s//&#8216;/\`}"
  s="${s//&#8217;/\'}"
  s="${s//&#8220;/\"}"
  s="${s//&#8221;/\"}"
  s="${s//&#8230;/…}"
  s="${s//&nbsp;/ }"
  echo "${s}"
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
