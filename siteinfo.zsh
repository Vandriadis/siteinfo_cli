#!/usr/bin/env zsh
# siteinfo.zsh — Main entry point for the SiteInfo interactive CLI tool
#
# Usage:
#   ./siteinfo.zsh            — launch interactive menu
#   ./siteinfo.zsh --help     — show help text
#   ./siteinfo.zsh --version  — show version
#
# Requires: curl, dig, host

# Disable implicit exit-on-error so modules can handle failures explicitly
setopt NO_ERR_EXIT NO_ERR_RETURN 2>/dev/null || true

# ---------------------------------------------------------------------------
# Resolve script directory so lib/ can be loaded regardless of CWD
# ---------------------------------------------------------------------------
SCRIPT_DIR="${0:A:h}"
LIB_DIR="${SCRIPT_DIR}/lib"

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
typeset -gr SITEINFO_VERSION="1.0.0"

# ---------------------------------------------------------------------------
# Load modules in dependency order
# ---------------------------------------------------------------------------
_load_modules() {
  local modules=(
    output.zsh    # Colors + print helpers — must be first
    utils.zsh     # URL utils, curl wrappers, pause
    dns.zsh       # DNS analysis
    http.zsh      # HTTP analysis
    detect.zsh    # Technology detection
    security.zsh  # Security headers
    whois.zsh     # WHOIS registration lookup
    threat.zsh    # Threat intel via external APIs
    menu.zsh      # Menu system + user-agent globals + event loop
  )

  for mod in "${modules[@]}"; do
    local mod_path="${LIB_DIR}/${mod}"
    if [[ ! -f "${mod_path}" ]]; then
      printf "\033[1;31m[ERROR]\033[0m Module not found: %s\n" "${mod_path}" >&2
      exit 1
    fi
    # shellcheck source=/dev/null
    source "${mod_path}"
  done
}

# ---------------------------------------------------------------------------
# show_help — usage / help text
# ---------------------------------------------------------------------------
show_help() {
  cat <<EOF

  SiteInfo v${SITEINFO_VERSION} — Website Analysis Tool

  USAGE
    ./siteinfo.zsh              Launch interactive menu
    ./siteinfo.zsh --help       Show this help text
    ./siteinfo.zsh --version    Show version

  REQUIREMENTS
    curl   HTTP requests
    dig    DNS lookups
    host   DNS lookups (fallback)

  MODULES
    DNS        A, AAAA, CNAME, NS, MX, TXT, SOA, PTR records
    HTTP       Status, headers, redirect chain, timing, cookies
    Detect     50+ technology fingerprints (frameworks, CMS, analytics)
    Security   Security header audit with scoring, cookie flag analysis
    WHOIS      Registrar, creation/expiry dates, name servers, countdown
    Threat     VirusTotal, Safe Browsing, AbuseIPDB reputation checks

  MENU OPTIONS
    1  Full site scan       Run all modules in one pass
    2  DNS information      DNS record lookup
    3  HTTP response info   Headers, timing, redirects
    4  Detect technologies  Technology fingerprinting
    5  Security headers     Header audit and scoring
    6  Desktop vs Mobile    Compare UA-specific responses
    7  WHOIS lookup         Registrar, dates, expiry countdown
    8  Threat intel         External threat reputation checks
    9  Exit

EOF
}

# ---------------------------------------------------------------------------
# show_version
# ---------------------------------------------------------------------------
show_version() {
  echo "siteinfo v${SITEINFO_VERSION}"
}

# ---------------------------------------------------------------------------
# main — entry point
# ---------------------------------------------------------------------------
main() {
  # Handle CLI flags
  case "${1:-}" in
    --help|-h)
      show_help
      exit 0
      ;;
    --version|-v)
      show_version
      exit 0
      ;;
  esac

  # Load all modules
  _load_modules

  # Load environment variables from .env (API keys, etc.)
  load_env_file

  # Sanity-check dependencies
  if ! check_dependencies; then
    exit 1
  fi

  # Start the interactive menu loop
  menu_loop
}

main "$@"
