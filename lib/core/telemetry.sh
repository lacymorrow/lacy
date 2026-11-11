#!/usr/bin/env bash

# Lacy Shell Telemetry: lightweight, anonymous usage tracking via Umami
# No PII collected. Respects DO_NOT_TRACK and LACY_NO_TELEMETRY.
# See: https://umami.is

# Plain assignments, not readonly: the plugin can be sourced again in the
# same shell, and readonly would print an error for each on every re-source.
_LACY_UMAMI_URL="${LACY_UMAMI_URL:-https://analytics.lacy.sh}"
_LACY_UMAMI_WEBSITE_ID="${LACY_UMAMI_WEBSITE_ID:-577521d7-3db7-4a77-a45c-3c97f21b5322}"
_LACY_TELEMETRY_FLAG="${LACY_SHELL_HOME}/.telemetry_sent"

# _lacy_json_escape_str is defined in constants.sh (shared helper).
# Guard: define here only if not already available (e.g., standalone sourcing).
if ! command -v _lacy_json_escape_str >/dev/null 2>&1; then
    _lacy_json_escape_str() {
        local s="$1"
        s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
        printf '%s' "$s"
    }
fi

# Send a tracking event to Umami (background, fail-silent)
_lacy_track_event() {
    [[ "${DO_NOT_TRACK:-}" == "1" ]] && return
    [[ "${LACY_NO_TELEMETRY:-}" == "1" ]] && return

    local event_name="${1:-unknown}"
    local method="${2:-unknown}"
    local version=""

    # Read version from package.json
    local pkg_file="${LACY_SHELL_HOME}/package.json"
    if [[ -f "$pkg_file" ]]; then
        version=$(grep '"version"' "$pkg_file" 2>/dev/null | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    fi

    local os_name
    os_name="$(uname -s 2>/dev/null || echo unknown)"
    local arch
    arch="$(uname -m 2>/dev/null || echo unknown)"

    # Escape all values for safe JSON interpolation
    event_name=$(_lacy_json_escape_str "$event_name")
    method=$(_lacy_json_escape_str "$method")
    version=$(_lacy_json_escape_str "${version:-unknown}")
    os_name=$(_lacy_json_escape_str "$os_name")
    arch=$(_lacy_json_escape_str "$arch")
    local shell_type
    shell_type=$(_lacy_json_escape_str "${LACY_SHELL_TYPE:-unknown}")
    local website_id
    website_id=$(_lacy_json_escape_str "$_LACY_UMAMI_WEBSITE_ID")

    (curl -sf --connect-timeout 3 --max-time 5 -X POST "${_LACY_UMAMI_URL}/api/send" \
        -H "Content-Type: application/json" \
        -H "User-Agent: lacy/${version}" \
        -d "{
            \"type\": \"event\",
            \"payload\": {
                \"hostname\": \"lacy.sh\",
                \"language\": \"\",
                \"referrer\": \"\",
                \"screen\": \"\",
                \"title\": \"Install\",
                \"url\": \"/install/${method}\",
                \"website\": \"${website_id}\",
                \"name\": \"${event_name}\",
                \"data\": {
                    \"method\": \"${method}\",
                    \"os\": \"${os_name}\",
                    \"arch\": \"${arch}\",
                    \"shell\": \"${shell_type}\",
                    \"version\": \"${version}\"
                }
            }
        }" >/dev/null 2>&1 &)
}

# One-time first-load tracking: detects install method and fires once
_lacy_track_first_load() {
    [[ "${DO_NOT_TRACK:-}" == "1" ]] && return
    [[ "${LACY_NO_TELEMETRY:-}" == "1" ]] && return
    [[ -f "$_LACY_TELEMETRY_FLAG" ]] && return

    # Detect install method
    local method="unknown"
    if [[ -L "$LACY_SHELL_HOME" ]]; then
        local link_target
        link_target=$(readlink "$LACY_SHELL_HOME" 2>/dev/null || true)
        if [[ "$link_target" == *"/Cellar/"* || "$link_target" == *"/homebrew/"* ]]; then
            method="brew"
        fi
    elif [[ -d "$LACY_SHELL_HOME/.git" ]]; then
        method="git"
    fi

    # Create flag file before sending (avoid duplicate sends)
    touch "$_LACY_TELEMETRY_FLAG" 2>/dev/null

    _lacy_track_event "first_load" "$method"
}

# ============================================================================
# Aptabase app telemetry (LAC-7620). Opt-in, off by default.
# ============================================================================
# Five events and nothing else: app_open, feature_used(name), purchase_started,
# purchase_completed, error(class). Lacy Shell has no purchases, so those two
# are never sent. No queries, no paths, no keys, no identifiers beyond a random
# per-shell session id. On only when `telemetry.enabled: true` in config.yaml
# (`lacy telemetry on`), and DO_NOT_TRACK=1 / LACY_NO_TELEMETRY=1 still win.

# Aptabase Cloud US app key for Lacy Shell. Ships in the plugin; not a secret.
_LACY_APTABASE_KEY="${LACY_APTABASE_KEY:-A-US-9570901449}"
_LACY_APTABASE_URL="${LACY_APTABASE_URL:-https://us.aptabase.com/api/v0/event}"
_LACY_APTABASE_SESSION=""

_lacy_telemetry_enabled() {
    [[ "${DO_NOT_TRACK:-}" == "1" ]] && return 1
    [[ "${LACY_NO_TELEMETRY:-}" == "1" ]] && return 1
    [[ "${LACY_TELEMETRY_ENABLED:-false}" == "true" ]]
}

# Send one event. Usage: _lacy_apt_send <event> [prop_name prop_value]
# Names and values are reduced to [A-Za-z0-9_.-], so free text cannot leave.
_lacy_apt_send() {
    _lacy_telemetry_enabled || return 0
    command -v curl >/dev/null 2>&1 || return 0

    local event="${1//[^A-Za-z0-9_.-]/}" pname="${2//[^A-Za-z0-9_.-]/}" pvalue="${3//[^A-Za-z0-9_.-]/}"
    [[ -n "$event" ]] || return 0

    if [[ -z "$_LACY_APTABASE_SESSION" ]]; then
        _LACY_APTABASE_SESSION="$(date +%s)${RANDOM}${RANDOM}${RANDOM}"
    fi

    local version="" pkg_file="${LACY_SHELL_HOME}/package.json"
    if [[ -f "$pkg_file" ]]; then
        version=$(grep '"version"' "$pkg_file" 2>/dev/null | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    fi
    version="${version//[^A-Za-z0-9_.-]/}"

    local props=""
    [[ -n "$pname" && -n "$pvalue" ]] && props=",\"props\":{\"${pname}\":\"${pvalue}\"}"

    local os_name
    os_name="$(uname -s 2>/dev/null || echo unknown)"
    os_name="${os_name//[^A-Za-z0-9_.-]/}"

    (curl -sf --connect-timeout 3 --max-time 5 -X POST "$_LACY_APTABASE_URL" \
        -H "Content-Type: application/json" \
        -H "App-Key: ${_LACY_APTABASE_KEY}" \
        -d "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"sessionId\":\"${_LACY_APTABASE_SESSION}\",\"eventName\":\"${event}\",\"systemProps\":{\"isDebug\":false,\"osName\":\"${os_name}\",\"appVersion\":\"${version:-unknown}\",\"sdkVersion\":\"lacy-sh@1\"}${props}}" \
        >/dev/null 2>&1 &)
}

_lacy_track_app_open() { _lacy_apt_send app_open; }
_lacy_track_feature() { _lacy_apt_send feature_used name "$1"; }
# Pass a short class such as "tool_failure", never a message.
_lacy_track_error() { _lacy_apt_send error class "$1"; }
