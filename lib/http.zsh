#!/usr/bin/env zsh
# http.zsh — HTTP response analysis module
# Uses curl to collect status, headers, redirects, cookies, timing.

setopt NO_ERR_EXIT NO_ERR_RETURN 2>/dev/null || true

# ---------------------------------------------------------------------------
# _curl_headers — fetch response headers for a URL (follows redirects)
# Captures the final response headers only
# ---------------------------------------------------------------------------
_curl_headers() {
  local url="${1}"
  local ua="${2:-${UA_DESKTOP}}"

  curl \
    --silent \
    --head \
    --max-time 15 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    --user-agent "${ua}" \
    "${url}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _curl_headers_all — fetch ALL response headers including intermediate hops
# Used to capture the full redirect chain
# ---------------------------------------------------------------------------
_curl_headers_all() {
  local url="${1}"
  local ua="${2:-${UA_DESKTOP}}"

  curl \
    --silent \
    --head \
    --max-time 15 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    --user-agent "${ua}" \
    --verbose \
    "${url}" 2>&1
}

# ---------------------------------------------------------------------------
# _curl_timing — get timing info using curl write-out
# ---------------------------------------------------------------------------
_curl_timing() {
  local url="${1}"
  local ua="${2:-${UA_DESKTOP}}"

  curl \
    --silent \
    --output /dev/null \
    --max-time 15 \
    --connect-timeout 8 \
    --location \
    --max-redirs 10 \
    --user-agent "${ua}" \
    --write-out '%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_starttransfer},%{time_total},%{http_code},%{url_effective},%{size_download},%{num_redirects}' \
    "${url}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _extract_header — pull a specific header value from a header block
# Usage: value=$(_extract_header "content-type" "${headers}")
# ---------------------------------------------------------------------------
_extract_header() {
  local name="${1}"
  local headers="${2}"
  echo "${headers}" | grep -i "^${name}:" | tail -1 | sed 's/^[^:]*: *//' | tr -d '\r'
}

# ---------------------------------------------------------------------------
# _extract_status — pull HTTP status line from headers
# ---------------------------------------------------------------------------
_extract_status() {
  local headers="${1}"
  echo "${headers}" | grep -i "^HTTP/" | tail -1 | tr -d '\r'
}

# ---------------------------------------------------------------------------
# _extract_status_code — just the numeric code
# ---------------------------------------------------------------------------
_extract_status_code() {
  local headers="${1}"
  _extract_status "${headers}" | awk '{print $2}'
}

# ---------------------------------------------------------------------------
# _build_redirect_chain — parse verbose curl output for redirect hops
# ---------------------------------------------------------------------------
_build_redirect_chain() {
  local verbose_output="${1}"
  local chain=()

  while IFS= read -r line; do
    # Lines like: < HTTP/1.1 301 Moved Permanently
    if [[ "${line}" =~ ^\<[[:space:]]HTTP/ ]]; then
      local status
      status=$(echo "${line}" | awk '{print $2, $3, $4, $5}')
      chain+=("${status}")
    fi
    # Lines like: * Issue another request to this URL: '...'
    if [[ "${line}" =~ "Issue another request to this URL: '" ]]; then
      local redir_url
      redir_url=$(echo "${line}" | sed "s/.*Issue another request to this URL: '//;s/'.*//")
      chain+=("  → ${redir_url}")
    fi
  done <<< "${verbose_output}"

  printf '%s\n' "${chain[@]}"
}

# ---------------------------------------------------------------------------
# _parse_cookies — extract Set-Cookie headers from a header block
# ---------------------------------------------------------------------------
_parse_cookies() {
  local headers="${1}"
  echo "${headers}" | grep -i "^set-cookie:" | tr -d '\r'
}

# ---------------------------------------------------------------------------
# run_http — main HTTP analysis function
# Usage: run_http "https://example.com"
# ---------------------------------------------------------------------------
run_http() {
  local url="${1}"

  print_section "HTTP Response — ${url}"
  print_info "Fetching response (following redirects)..."

  # ── Timing + metadata via write-out ─────────────────────────────────────
  local timing_raw
  timing_raw=$(_curl_timing "${url}" "${UA_DESKTOP}")

  if [[ -z "${timing_raw}" ]]; then
    print_error "curl failed — could not reach ${url}"
    print_error "Check the URL, your network, or try with http:// instead."
    print_section_end
    return 1
  fi

  # Parse CSV timing output
  local t_dns t_connect t_tls t_pretransfer t_first t_total
  local http_code final_url size_dl num_redirects
  IFS=',' read -r t_dns t_connect t_tls t_pretransfer t_first t_total \
    http_code final_url size_dl num_redirects <<< "${timing_raw}"

  # ── Final headers (after all redirects) ──────────────────────────────────
  local final_headers
  final_headers=$(_curl_headers "${url}" "${UA_DESKTOP}")

  local server ct x_powered content_len cache_control
  server=$(_extract_header "server" "${final_headers}")
  ct=$(_extract_header "content-type" "${final_headers}")
  x_powered=$(_extract_header "x-powered-by" "${final_headers}")
  content_len=$(_extract_header "content-length" "${final_headers}")
  cache_control=$(_extract_header "cache-control" "${final_headers}")
  local via
  via=$(_extract_header "via" "${final_headers}")
  local cf_ray
  cf_ray=$(_extract_header "cf-ray" "${final_headers}")
  local cf_cache
  cf_cache=$(_extract_header "cf-cache-status" "${final_headers}")

  # ── Status ───────────────────────────────────────────────────────────────
  print_separator
  local sc="${http_code:-???}"
  local sc_color
  sc_color=$(status_color "${sc}")
  print_key_value "Status Code" "${sc}" "${sc_color}"
  print_key_value "Final URL" "${final_url:-${url}}" "cyan"
  print_key_value "Redirects" "${num_redirects:-0}" "white"

  # ── Timing ───────────────────────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Timing${CLR_RESET}\n"
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  %s\n" "DNS Lookup:"      "${t_dns}s"
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  %s\n" "TCP Connect:"     "${t_connect}s"
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  %s\n" "TLS Handshake:"   "${t_tls}s"
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  %s\n" "First Byte (TTFB):" "${t_first}s"
  printf "  ${CLR_DIM}%-${KV_WIDTH}s${CLR_RESET}  ${CLR_BOLD_WHITE}%s${CLR_RESET}\n" "Total Time:" "${t_total}s"

  # ── Server info ──────────────────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Server${CLR_RESET}\n"
  print_key_value "Server" "${server:-(not disclosed)}" "white"
  print_key_value "X-Powered-By" "${x_powered:-(not set)}" "white"
  [[ -n "${via}" ]]      && print_key_value "Via" "${via}" "white"
  [[ -n "${cf_ray}" ]]   && print_key_value "Cloudflare Ray" "${cf_ray}" "white"
  [[ -n "${cf_cache}" ]] && print_key_value "CF-Cache-Status" "${cf_cache}" "white"

  # ── Content ──────────────────────────────────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}Content${CLR_RESET}\n"
  print_key_value "Content-Type" "${ct:-(not set)}" "white"
  print_key_value "Content-Length" "${content_len:-(not set)}" "white"
  local dl_human
  dl_human=$(bytes_to_human "${size_dl:-0}")
  print_key_value "Downloaded" "${dl_human}" "white"
  print_key_value "Cache-Control" "${cache_control:-(not set)}" "white"

  # ── Redirect chain ───────────────────────────────────────────────────────
  if (( ${num_redirects:-0} > 0 )); then
    print_separator
    printf "  ${CLR_BOLD_YELLOW}Redirect Chain (%d hops)${CLR_RESET}\n" "${num_redirects}"
    local verbose_out
    verbose_out=$(_curl_headers_all "${url}" "${UA_DESKTOP}")
    local chain
    chain=$(_build_redirect_chain "${verbose_out}")
    if [[ -n "${chain}" ]]; then
      while IFS= read -r hop; do
        [[ -z "${hop}" ]] && continue
        print_list_item "${hop}"
      done <<< "${chain}"
    fi
  fi

  # ── Cookies ──────────────────────────────────────────────────────────────
  local cookies
  cookies=$(_parse_cookies "${final_headers}")
  if [[ -n "${cookies}" ]]; then
    print_separator
    printf "  ${CLR_BOLD_YELLOW}Set-Cookie Headers${CLR_RESET}\n"
    while IFS= read -r ck; do
      [[ -z "${ck}" ]] && continue
      local ck_val
      ck_val=$(echo "${ck}" | sed 's/^set-cookie: *//i')
      print_list_item "${ck_val}"
    done <<< "${cookies}"
  fi

  # ── All response headers (collapsed view) ────────────────────────────────
  print_separator
  printf "  ${CLR_BOLD_YELLOW}All Response Headers${CLR_RESET}\n"
  while IFS= read -r hdr; do
    hdr="${hdr%$'\r'}"
    [[ -z "${hdr}" ]] && continue
    printf "  ${CLR_DIM}%-32s${CLR_RESET}  %s\n" \
      "${hdr%%:*}" \
      "${${hdr#*:}## }"
  done < <(echo "${final_headers}" | grep -v '^HTTP/')

  print_section_end
}
