#!/usr/bin/env zsh
# detect.zsh — Technology detection module
# Downloads HTML and HTTP headers, then pattern-matches against known signatures.
#
# IMPORTANT zsh compatibility note:
# On macOS zsh, arr["key"] and arr['key'] store the literal quote chars as part
# of the key name. All associative array subscripts MUST use unquoted variable
# expansion: arr[$var] or bare literals with no spaces: arr[BareKey].
# Keys with spaces are stored as underscore-separated identifiers; display names
# use the mapping in TECH_DISPLAY_NAMES.

# ---------------------------------------------------------------------------
# Technology pattern database.
# Keys use underscore separators (no spaces) to stay compatible with zsh
# associative array subscript rules.
# Patterns are pipe-delimited extended regex.
# ---------------------------------------------------------------------------
typeset -gA TECH_PATTERNS

# ── JavaScript Frameworks ──────────────────────────────────────────────────
TECH_PATTERNS[React]='react\.js|react\.min\.js|react-dom|__REACT_DEVTOOLS|data-reactroot|data-reactid|_reactFiber'
TECH_PATTERNS[Next.js]='__NEXT_DATA__|_next\/static|__nextjs|/_next/|"buildId":'
TECH_PATTERNS[Vue.js]='vue\.js|vue\.min\.js|__vue__|data-v-[a-f0-9]+|vue@[0-9]|vuex'
TECH_PATTERNS[Nuxt.js]='__nuxt|__NUXT__|_nuxt\/|nuxt\.config|<nuxt'
TECH_PATTERNS[Angular]='ng-version=|angular\.js|angular\.min\.js|ng-app|ng-controller|zone\.js'
TECH_PATTERNS[Svelte]='__svelte_|svelte-|\.svelte\b'
TECH_PATTERNS[Ember.js]='ember\.js|ember\.min\.js|Ember\.Application|data-ember-action'
TECH_PATTERNS[Backbone.js]='backbone\.js|Backbone\.View|Backbone\.Model'
TECH_PATTERNS[jQuery]='jquery[.-][0-9]|jquery\.min\.js|jQuery v[0-9]'
TECH_PATTERNS[Alpine.js]='x-data=|x-bind:|x-on:|alpine\.js|alpinejs'

# ── CSS Frameworks ──────────────────────────────────────────────────────────
TECH_PATTERNS[Bootstrap]='bootstrap\.min\.css|bootstrap\.css|bootstrap\.min\.js'
TECH_PATTERNS[Tailwind_CSS]='tailwindcss|cdn\.tailwindcss\.com|tailwind\.min\.css'
TECH_PATTERNS[Bulma]='bulma\.css|bulma\.min\.css'
TECH_PATTERNS[Foundation]='foundation\.css|foundation\.min\.js'
TECH_PATTERNS[Materialize]='materialize\.css|materialize\.min\.js|M\.AutoInit'

# ── Analytics / Tag Management ─────────────────────────────────────────────
TECH_PATTERNS[Google_Analytics]='google-analytics\.com/analytics\.js|googletagmanager\.com/gtag|UA-[0-9]+-[0-9]+|G-[A-Z0-9]+'
TECH_PATTERNS[Google_Tag_Manager]='googletagmanager\.com/gtm\.js|GTM-[A-Z0-9]+|google_tag_manager'
TECH_PATTERNS[Meta_Pixel]='connect\.facebook\.net/.*fbevents\.js|fbq\(|_fbq\b|FB\.init\b'
TECH_PATTERNS[Hotjar]='static\.hotjar\.com|hj\(|_hjSettings|hotjar\.com'
TECH_PATTERNS[Segment]='cdn\.segment\.com|analytics\.identify|analytics\.track\b'
TECH_PATTERNS[Mixpanel]='cdn\.mxpnl\.com|mixpanel\.track|api\.mixpanel\.com'
TECH_PATTERNS[Heap_Analytics]='heapanalytics\.com|heap\.identify|window\.heap\b'
TECH_PATTERNS[Plausible]='plausible\.io/js|data-domain='
TECH_PATTERNS[Matomo]='matomo\.js|piwik\.js|_paq\.push'

# ── Security / Anti-bot ────────────────────────────────────────────────────
TECH_PATTERNS[reCAPTCHA]='google\.com/recaptcha|grecaptcha\b|recaptcha\.net'
TECH_PATTERNS[hCaptcha]='hcaptcha\.com|h-captcha\b|HCaptcha'
TECH_PATTERNS[Cloudflare]='cf-ray:|cloudflare|__cfduid|_cf_bm|cdn\.cloudflare\.net'
TECH_PATTERNS[Fastly]='x-served-by:.*cache|x-fastly-|fastly-io'
TECH_PATTERNS[Akamai]='x-akamai-|akamaized\.net|edgesuite\.net'

# ── CMS / Platforms ────────────────────────────────────────────────────────
TECH_PATTERNS[WordPress]='wp-content/|wp-includes/|xmlrpc\.php|wp-json/|WordPress [0-9]'
TECH_PATTERNS[Drupal]='Drupal\.settings|drupal\.js|/sites/default/files|Drupal [0-9]'
TECH_PATTERNS[Joomla]='/components/com_|joomla|/media/jui/'
TECH_PATTERNS[Shopify]='cdn\.shopify\.com|Shopify\.theme|myshopify\.com|shopify-features'
TECH_PATTERNS[Wix]='wix\.com|wixstatic\.com|wix-warmup-data'
TECH_PATTERNS[Squarespace]='squarespace\.com|static1\.squarespace\.com|squarespace-headers'
TECH_PATTERNS[Webflow]='webflow\.com|webflow\.io|wf-form-'
TECH_PATTERNS[Ghost]='ghost\.org|content\.ghost\.io|ghost-theme'

# ── E-commerce ─────────────────────────────────────────────────────────────
TECH_PATTERNS[WooCommerce]='woocommerce|wc-ajax=|wc_add_to_cart'
TECH_PATTERNS[Magento]='Mage\.Cookies|magento|mage-|skin/frontend/'
TECH_PATTERNS[PrestaShop]='prestashop|presta_shop'
TECH_PATTERNS[BigCommerce]='bigcommerce\.com|cdn[0-9]\.bigcommerce\.com'

# ── Web Server (from headers) ──────────────────────────────────────────────
TECH_PATTERNS[Nginx]='server: nginx'
TECH_PATTERNS[Apache]='server: apache'
TECH_PATTERNS[Caddy]='server: caddy'
TECH_PATTERNS[LiteSpeed]='server: litespeed|x-litespeed-cache'
TECH_PATTERNS[IIS]='server: microsoft-iis|x-aspnet-version'

# ── Fonts / CDN ────────────────────────────────────────────────────────────
TECH_PATTERNS[Google_Fonts]='fonts\.googleapis\.com|fonts\.gstatic\.com'
TECH_PATTERNS[Adobe_Fonts]='use\.typekit\.net|use\.typekit\.com'
TECH_PATTERNS[Font_Awesome]='font-awesome|fontawesome\.com'

# ── Libraries ──────────────────────────────────────────────────────────────
TECH_PATTERNS[Lodash]='lodash\.js|lodash\.min\.js'
TECH_PATTERNS[Moment.js]='moment\.js|moment\.min\.js|moment\.locale\b'
TECH_PATTERNS[Chart.js]='chart\.js|chart\.min\.js|new Chart\('
TECH_PATTERNS[D3.js]='d3\.js|d3\.min\.js|d3\.select\b'
TECH_PATTERNS[Three.js]='three\.js|three\.min\.js|new THREE\.'
TECH_PATTERNS[GSAP]='gsap\.min\.js|TweenMax|TweenLite|gsap\.to\b'
TECH_PATTERNS[Stripe]='js\.stripe\.com|Stripe\.setPublishableKey|stripe\.com/v3'
TECH_PATTERNS[Intercom]='widget\.intercom\.io|intercomSettings'
TECH_PATTERNS[Zendesk]='zendesk\.com|zopim\.com'
TECH_PATTERNS[Sentry]='browser\.sentry-cdn\.com|Sentry\.init\b|sentry\.io'

# ---------------------------------------------------------------------------
# Display names mapping: internal key → human-readable name
# ---------------------------------------------------------------------------
typeset -gA TECH_DISPLAY_NAMES
TECH_DISPLAY_NAMES[Tailwind_CSS]="Tailwind CSS"
TECH_DISPLAY_NAMES[Google_Analytics]="Google Analytics"
TECH_DISPLAY_NAMES[Google_Tag_Manager]="Google Tag Manager"
TECH_DISPLAY_NAMES[Meta_Pixel]="Meta Pixel"
TECH_DISPLAY_NAMES[Heap_Analytics]="Heap Analytics"
TECH_DISPLAY_NAMES[Google_Fonts]="Google Fonts"
TECH_DISPLAY_NAMES[Adobe_Fonts]="Adobe Fonts"
TECH_DISPLAY_NAMES[Font_Awesome]="Font Awesome"

# ---------------------------------------------------------------------------
# Category → ordered list of tech keys (internal underscore format)
# ---------------------------------------------------------------------------
typeset -ga TECH_CATEGORY_MAP
TECH_CATEGORY_MAP=(
  "JS Frameworks:React"
  "JS Frameworks:Next.js"
  "JS Frameworks:Vue.js"
  "JS Frameworks:Nuxt.js"
  "JS Frameworks:Angular"
  "JS Frameworks:Svelte"
  "JS Frameworks:Ember.js"
  "JS Frameworks:Backbone.js"
  "JS Frameworks:jQuery"
  "JS Frameworks:Alpine.js"
  "CSS Frameworks:Bootstrap"
  "CSS Frameworks:Tailwind_CSS"
  "CSS Frameworks:Bulma"
  "CSS Frameworks:Foundation"
  "CSS Frameworks:Materialize"
  "Analytics & Tracking:Google_Analytics"
  "Analytics & Tracking:Google_Tag_Manager"
  "Analytics & Tracking:Meta_Pixel"
  "Analytics & Tracking:Hotjar"
  "Analytics & Tracking:Segment"
  "Analytics & Tracking:Mixpanel"
  "Analytics & Tracking:Heap_Analytics"
  "Analytics & Tracking:Plausible"
  "Analytics & Tracking:Matomo"
  "Security & CDN:reCAPTCHA"
  "Security & CDN:hCaptcha"
  "Security & CDN:Cloudflare"
  "Security & CDN:Fastly"
  "Security & CDN:Akamai"
  "CMS & Platforms:WordPress"
  "CMS & Platforms:Drupal"
  "CMS & Platforms:Joomla"
  "CMS & Platforms:Shopify"
  "CMS & Platforms:Wix"
  "CMS & Platforms:Squarespace"
  "CMS & Platforms:Webflow"
  "CMS & Platforms:Ghost"
  "E-Commerce:WooCommerce"
  "E-Commerce:Magento"
  "E-Commerce:PrestaShop"
  "E-Commerce:BigCommerce"
  "Web Server:Nginx"
  "Web Server:Apache"
  "Web Server:Caddy"
  "Web Server:LiteSpeed"
  "Web Server:IIS"
  "Libraries & Other:Google_Fonts"
  "Libraries & Other:Adobe_Fonts"
  "Libraries & Other:Font_Awesome"
  "Libraries & Other:Lodash"
  "Libraries & Other:Moment.js"
  "Libraries & Other:Chart.js"
  "Libraries & Other:D3.js"
  "Libraries & Other:Three.js"
  "Libraries & Other:GSAP"
  "Libraries & Other:Stripe"
  "Libraries & Other:Intercom"
  "Libraries & Other:Zendesk"
  "Libraries & Other:Sentry"
)

# ---------------------------------------------------------------------------
# _display_name — return human-readable name for an internal key
# Usage: name=$(_display_name "Tailwind_CSS")  →  "Tailwind CSS"
# ---------------------------------------------------------------------------
_display_name() {
  local key="${1}"
  local mapped="${TECH_DISPLAY_NAMES[$key]}"
  if [[ -n "${mapped}" ]]; then
    echo "${mapped}"
  else
    echo "${key//_/ }"   # fallback: replace underscores with spaces
  fi
}

# ---------------------------------------------------------------------------
# _fetch_page — download HTML + headers for analysis
# ---------------------------------------------------------------------------
_fetch_page() {
  local url="${1}"
  local ua="${2:-${UA_DESKTOP}}"

  curl \
    --silent \
    --include \
    --max-time 20 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    --compressed \
    --user-agent "${ua}" \
    "${url}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# run_detect — technology detection main function
# Usage: run_detect "https://example.com"
# ---------------------------------------------------------------------------
run_detect() {
  local url="${1}"

  print_section "Technology Detection — ${url}"
  print_info "Downloading page content for analysis..."

  local page_content
  page_content=$(_fetch_page "${url}" "${UA_DESKTOP}")

  if [[ -z "${page_content}" ]]; then
    print_error "Failed to download page content from ${url}"
    print_section_end
    return 1
  fi

  # Convert to lowercase for case-insensitive matching
  local content_lc
  content_lc=$(echo "${page_content}" | LC_ALL=C tr '[:upper:]' '[:lower:]')

  print_info "Scanning ${#content_lc} bytes for technology fingerprints..."
  echo ""

  # Declare all intermediate variables BEFORE any loop.
  # NEVER use arr["${var}"] — on macOS zsh this embeds literal quote chars.
  # Use arr[$var] with an unquoted variable subscript instead.
  local -A detected_techs detected_patterns
  local total_detected=0
  local _tech _pattern _sub_parts _sub _snippet

  # ── Scan all patterns ────────────────────────────────────────────────────
  for _tech _pattern in "${(@kv)TECH_PATTERNS}"; do
    if echo "${content_lc}" | grep -qiE "${_pattern}" 2>/dev/null; then
      detected_techs[$_tech]=1
      # Split on | using zsh (s:|:) flag; find first matching sub-pattern
      _snippet=""
      _sub_parts=("${(s:|:)_pattern}")
      for _sub in "${_sub_parts[@]}"; do
        _snippet=$(echo "${content_lc}" | grep -iEo "${_sub}" 2>/dev/null | head -1)
        [[ -n "${_snippet}" ]] && break
      done
      detected_patterns[$_tech]="${_snippet:-${_pattern%%|*}}"
      (( total_detected++ )) || true
    fi
  done

  # ── Display results grouped by category ──────────────────────────────────
  local _entry _cat _tkey _current_cat="" _matched _dname

  for _entry in "${TECH_CATEGORY_MAP[@]}"; do
    _cat="${_entry%%:*}"
    _tkey="${_entry#*:}"

    [[ "${detected_techs[$_tkey]}" != "1" ]] && continue

    if [[ "${_cat}" != "${_current_cat}" ]]; then
      print_separator
      printf "  ${CLR_BOLD_YELLOW}%s${CLR_RESET}\n" "${_cat}"
      _current_cat="${_cat}"
    fi

    _dname=$(_display_name "${_tkey}")
    _matched="${detected_patterns[$_tkey]:-?}"
    printf "  ${CLR_BOLD_GREEN}[✔]${CLR_RESET} ${CLR_BOLD_WHITE}%-24s${CLR_RESET}  ${CLR_DIM}via: %s${CLR_RESET}\n" "${_dname}" "${_matched}"
  done

  # ── Summary ───────────────────────────────────────────────────────────────
  print_separator
  echo ""
  if [[ "${total_detected}" -gt 0 ]]; then
    print_success "Detected ${total_detected} technologies"
  else
    print_warning "No known technologies detected (may use custom stack or heavy JS rendering)"
    print_info "Note: SPA frameworks may not be detectable via static HTML alone"
  fi

  # Page metadata
  local title html_len
  title=$(echo "${page_content}" | grep -oi '<title>[^<]*</title>' | sed 's/<[^>]*>//g' | head -1 | tr -d '\r\n')
  [[ -n "${title}" ]] && print_key_value "Page Title" "${title}" "cyan"

  html_len=${#content_lc}
  print_key_value "Page Size" "$(bytes_to_human ${html_len})" "white"

  print_section_end
}
