#!/usr/bin/env bash

# Lacy Shell Telemetry — lightweight, anonymous usage tracking via Umami
# No PII collected. Respects DO_NOT_TRACK and LACY_NO_TELEMETRY.
# See: https://umami.is

readonly _LACY_UMAMI_URL="${LACY_UMAMI_URL:-https://analytics.lacy.sh}"
readonly _LACY_UMAMI_WEBSITE_ID="${LACY_UMAMI_WEBSITE_ID:-577521d7-3db7-4a77-a45c-3c97f21b5322}"
readonly _LACY_TELEMETRY_FLAG="${LACY_SHELL_HOME}/.telemetry_sent"

# Escape a string for safe JSON embedding — handles \, ", and control chars.
# Usage: escaped=$(_lacy_json_escape_str "$value")
_lacy_json_escape_str() {
    local s="$1"
    s="${s//\\/\\\\}"   # \ → \\
    s="${s//\"/\\\"}"   # " → \"
    s="${s//$'\n'/\\n}" # newline → \n
    s="${s//$'\r'/\\r}" # carriage return → \r
    s="${s//$'\t'/\\t}" # tab → \t
    printf '%s' "$s"
}

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

# One-time first-load tracking — detects install method and fires once
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
