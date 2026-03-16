#!/usr/bin/env zsh
# utils.zsh — Shared utilities: URL validation, dependency checks, prompt helpers

# ---------------------------------------------------------------------------
# check_dependencies — verify required system tools are available
# ---------------------------------------------------------------------------
check_dependencies() {
  local missing=()
  local deps=(curl dig host)

  for dep in "${deps[@]}"; do
    if ! command -v "${dep}" &>/dev/null; then
      missing+=("${dep}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    print_error "Missing required tools: ${missing[*]}"
    print_info "Install them with your package manager (e.g. brew install ${missing[*]})"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# normalize_url — ensure URL has a scheme; default to https://
# Usage: normalized=$(normalize_url "example.com")
# ---------------------------------------------------------------------------
normalize_url() {
  local raw="${1}"
  # Strip leading/trailing whitespace
  raw="${raw## }"
  raw="${raw%% }"

  if [[ -z "${raw}" ]]; then
    echo ""
    return 1
  fi

  # Already has a scheme
  if [[ "${raw}" == http://* || "${raw}" == https://* ]]; then
    echo "${raw}"
    return 0
  fi

  # Add https by default
  echo "https://${raw}"
}

# ---------------------------------------------------------------------------
# validate_url — basic structural validation
# Returns 0 if looks valid, 1 otherwise
# ---------------------------------------------------------------------------
validate_url() {
  local url="${1}"
  # Must start with http:// or https://
  if [[ ! "${url}" =~ ^https?://[a-zA-Z0-9._-]+.*$ ]]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# extract_host — pull the hostname out of a full URL
# Usage: host=$(extract_host "https://www.example.com/path?q=1")
# ---------------------------------------------------------------------------
extract_host() {
  local url="${1}"
  # Remove scheme
  local no_scheme="${url#*://}"
  # Remove path, query, fragment
  local host="${no_scheme%%/*}"
  # Remove port
  host="${host%%:*}"
  echo "${host}"
}

# ---------------------------------------------------------------------------
# prompt_url — interactive URL prompt with normalization and validation
# Sets global CURRENT_URL on success
# Returns 0 on success, 1 on empty/abort
# ---------------------------------------------------------------------------
prompt_url() {
  local prompt_label="${1:-Enter URL}"
  local raw_url

  printf "\n  ${CLR_BOLD_WHITE}${prompt_label}${CLR_RESET} ${CLR_DIM}(e.g. example.com or https://example.com)${CLR_RESET}\n"
  printf "  ${CLR_CYAN}❯${CLR_RESET} "
  read -r raw_url

  if [[ -z "${raw_url}" ]]; then
    print_warning "No URL entered. Returning to menu."
    return 1
  fi

  local normalized
  normalized=$(normalize_url "${raw_url}")

  if ! validate_url "${normalized}"; then
    print_error "Invalid URL: '${normalized}'"
    return 1
  fi

  CURRENT_URL="${normalized}"
  return 0
}

# ---------------------------------------------------------------------------
# run_curl — wrapper around curl with common flags
# Usage: output=$(run_curl [extra flags...] "URL")
# ---------------------------------------------------------------------------
run_curl() {
  curl \
    --silent \
    --max-time 15 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    "$@"
}

# ---------------------------------------------------------------------------
# run_curl_head — fetch only headers, follow redirects
# ---------------------------------------------------------------------------
run_curl_head() {
  curl \
    --silent \
    --head \
    --max-time 15 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    "$@"
}

# ---------------------------------------------------------------------------
# run_curl_verbose — capture full verbose output (headers + body metadata)
# Writes headers to stdout, redirects verbose/errors to /dev/null
# ---------------------------------------------------------------------------
run_curl_verbose() {
  curl \
    --silent \
    --include \
    --max-time 15 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    "$@"
}

# ---------------------------------------------------------------------------
# ms_to_human — convert milliseconds to human string
# ---------------------------------------------------------------------------
ms_to_human() {
  local ms="${1}"
  if (( ms < 1000 )); then
    echo "${ms}ms"
  else
    printf "%.2fs" "$(echo "scale=2; ${ms}/1000" | bc 2>/dev/null || echo '?')"
  fi
}

# ---------------------------------------------------------------------------
# bytes_to_human — convert byte count to human-readable
# ---------------------------------------------------------------------------
bytes_to_human() {
  local bytes="${1:-0}"
  if (( bytes < 1024 )); then
    echo "${bytes} B"
  elif (( bytes < 1048576 )); then
    printf "%.1f KB" "$(echo "scale=1; ${bytes}/1024" | bc 2>/dev/null || echo '?')"
  else
    printf "%.2f MB" "$(echo "scale=2; ${bytes}/1048576" | bc 2>/dev/null || echo '?')"
  fi
}

# ---------------------------------------------------------------------------
# pause — wait for user to press Enter before continuing
# ---------------------------------------------------------------------------
pause() {
  echo ""
  printf "  ${CLR_DIM}Press Enter to return to the menu...${CLR_RESET}"
  read -r
}

# ---------------------------------------------------------------------------
# status_color — return a color name based on HTTP status code
# ---------------------------------------------------------------------------
status_color() {
  local code="${1}"
  case "${code}" in
    2*)  echo "green"   ;;
    3*)  echo "yellow"  ;;
    4*)  echo "red"     ;;
    5*)  echo "red"     ;;
    *)   echo "white"   ;;
  esac
}

# ---------------------------------------------------------------------------
# lowercase — portable lowercase conversion
# ---------------------------------------------------------------------------
lowercase() {
  echo "${1}" | tr '[:upper:]' '[:lower:]'
}
