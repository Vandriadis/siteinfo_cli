#!/usr/bin/env zsh
# utils.zsh — Shared utilities: URL validation, dependency checks, prompt helpers

# Default runtime profile for external checks: quick | standard | deep
typeset -g SITEINFO_PROFILE="${SITEINFO_PROFILE:-standard}"
typeset -g SITEINFO_CACHE_DIR="${SITEINFO_CACHE_DIR:-${SCRIPT_DIR}/.cache/siteinfo}"
typeset -g SITEINFO_UI_MODE="${SITEINFO_UI_MODE:-expanded}"

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
# load_env_file — source .env from project root if present
# Exports loaded variables for child processes.
# ---------------------------------------------------------------------------
load_env_file() {
  local env_path="${SCRIPT_DIR}/.env"
  if [[ -f "${env_path}" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${env_path}"
    set +a
  fi
}

# ---------------------------------------------------------------------------
# ensure_cache_dir — create cache directory if needed
# ---------------------------------------------------------------------------
ensure_cache_dir() {
  mkdir -p "${SITEINFO_CACHE_DIR}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# cache_key_hash — stable hash for cache keys
# ---------------------------------------------------------------------------
cache_key_hash() {
  local key="${1}"
  if command -v shasum &>/dev/null; then
    echo -n "${key}" | shasum -a 256 | awk '{print $1}'
  else
    echo -n "${key}" | md5 | awk '{print $NF}'
  fi
}

# ---------------------------------------------------------------------------
# cache_get — read cached value if file age <= ttl seconds
# Usage: cache_get "service" "key" 3600
# ---------------------------------------------------------------------------
cache_get() {
  local service="${1}"
  local key="${2}"
  local ttl="${3:-3600}"
  local hash path now mtime age

  ensure_cache_dir
  hash=$(cache_key_hash "${service}|${key}")
  path="${SITEINFO_CACHE_DIR}/${service}_${hash}.cache"
  [[ ! -f "${path}" ]] && return 1

  now=$(date +%s)
  mtime=$(stat -f "%m" "${path}" 2>/dev/null || echo 0)
  age=$(( now - mtime ))
  (( age > ttl )) && return 1

  < "${path}" tr -d '\r'
  return 0
}

# ---------------------------------------------------------------------------
# cache_set — write value to cache
# Usage: cache_set "service" "key" "value"
# ---------------------------------------------------------------------------
cache_set() {
  local service="${1}"
  local key="${2}"
  local value="${3}"
  local hash path

  ensure_cache_dir
  hash=$(cache_key_hash "${service}|${key}")
  path="${SITEINFO_CACHE_DIR}/${service}_${hash}.cache"
  printf "%s" "${value}" > "${path}"
}

# ---------------------------------------------------------------------------
# ui_is_compact — helper to check compact output mode
# ---------------------------------------------------------------------------
ui_is_compact() {
  [[ "${SITEINFO_UI_MODE:-expanded}" == "compact" ]]
}

# ---------------------------------------------------------------------------
# run_with_spinner — run command in background with spinner animation
# Usage: out=$(run_with_spinner "Message" command arg1 arg2 ...)
# ---------------------------------------------------------------------------
run_with_spinner() {
  local message="${1}"
  shift

  local tmp_file
  tmp_file=$(mktemp "/tmp/siteinfo-spinner.XXXXXX")

  "$@" > "${tmp_file}" 2>/dev/null &
  local pid=$!

  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=1
  while kill -0 "${pid}" 2>/dev/null; do
    printf "\r  ${CLR_CYAN}%s${CLR_RESET} ${CLR_DIM}%s...${CLR_RESET}" "${frames[$i]}" "${message}"
    i=$(( (i % ${#frames[@]}) + 1 ))
    sleep 0.08
  done
  wait "${pid}" 2>/dev/null
  printf "\r\033[K"

  < "${tmp_file}"
  rm -f "${tmp_file}"
}

# ---------------------------------------------------------------------------
# print_scan_progress — animated high-level scan progress bar
# Usage: print_scan_progress 2 6 "HTTP"
# ---------------------------------------------------------------------------
print_scan_progress() {
  local current="${1}"
  local total="${2}"
  local label="${3:-Step}"
  local width=24
  local filled=$(( current * width / total ))
  local pct=$(( current * 100 / total ))
  local bar="" i

  i=0
  while (( i < filled )); do bar+="█"; (( i++ )); done
  while (( i < width )); do bar+="░"; (( i++ )); done

  printf "\r  ${CLR_DIM}Progress:${CLR_RESET} ${CLR_BOLD_CYAN}%s${CLR_RESET} ${CLR_BOLD_WHITE}%3d%%${CLR_RESET} ${CLR_DIM}(%d/%d • %s)${CLR_RESET}" \
    "${bar}" "${pct}" "${current}" "${total}" "${label}"
  if (( current == total )); then
    echo ""
  fi
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
