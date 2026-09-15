#!/usr/bin/env bash

# Lacy Shell Installation Script
# https://github.com/lacymorrow/lacy
#
# Install methods:
#   curl -fsSL https://lacy.sh/install | bash
#   npx lacy
#   brew install lacymorrow/tap/lacy
#
# Runs on bash 3.2 (macOS /bin/bash) and newer.
#
# Environment:
#   LACY_NO_NODE=1       Skip the Node installer
#   NO_COLOR=1           Plain output
#   DO_NOT_TRACK=1       No install analytics
#   LACY_REPO_URL        Clone from another git URL (tests use file://)
#   LACY_REF             Install this branch, tag, or commit sha instead of
#                        the latest release tag (CI installs the PR commit)
#   LACY_TARBALL_URL     Archive base for the no-git fallback
#                        (<base>/tags/<tag>.tar.gz or <base>/heads/main.tar.gz)

set -e

if [[ -n "${NO_COLOR:-}" ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" DIM="" NC=""
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
fi

INSTALL_DIR="${HOME}/.lacy"
CONFIG_FILE="${INSTALL_DIR}/config.yaml"
DEFAULT_REPO_URL="https://github.com/lacymorrow/lacy.git"
REPO_URL="${LACY_REPO_URL:-$DEFAULT_REPO_URL}"
if [[ -n "${LACY_TARBALL_URL:-}" ]]; then
    TARBALL_BASE="$LACY_TARBALL_URL"
elif [[ "$REPO_URL" == "$DEFAULT_REPO_URL" ]]; then
    TARBALL_BASE="https://github.com/lacymorrow/lacy/archive/refs"
else
    TARBALL_BASE=""
fi

# Keep in sync with LACY_TOOL_LIST in lib/core/constants.sh (tests check).
TOOL_LIST=(lash claude opencode gemini codex hermes copilot goose amp aider)

# Never let git stop to ask for credentials (a bad URL on GitHub asks).
export GIT_TERMINAL_PROMPT=0

SELECTED_TOOL=""
CUSTOM_COMMAND=""
DETECTED_SHELL=""
MODE=""
LAST_ERROR=""
STAGE_DIR=""

cleanup() {
    [[ -n "$STAGE_DIR" && -e "$STAGE_DIR" ]] && command rm -rf "$STAGE_DIR"
    return 0
}
trap cleanup EXIT

info()  { printf "${BLUE}%s${NC}\n" "$1"; }
ok()    { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}%s${NC}\n" "$1"; }
error() { printf "${RED}%s${NC}\n" "$1" >&2; }

# ============================================================================
# Analytics: anonymous install counts via Umami. No PII. Respects DO_NOT_TRACK.
# ============================================================================

UMAMI_URL="${LACY_UMAMI_URL:-https://analytics.lacy.sh}"
UMAMI_WEBSITE_ID="${LACY_UMAMI_WEBSITE_ID:-577521d7-3db7-4a77-a45c-3c97f21b5322}"

track_event() {
    [[ "${DO_NOT_TRACK:-}" == "1" ]] && return 0
    [[ "${LACY_NO_TELEMETRY:-}" == "1" ]] && return 0

    local event_name="${1:-install}"
    local method="${2:-curl}"
    local version
    version=$(get_installed_version)

    (curl -sf --connect-timeout 3 --max-time 5 -X POST "${UMAMI_URL}/api/send" \
        -H "Content-Type: application/json" \
        -H "User-Agent: lacy-install/${version:-unknown}" \
        -d "{
            \"type\": \"event\",
            \"payload\": {
                \"hostname\": \"lacy.sh\",
                \"language\": \"\",
                \"referrer\": \"\",
                \"screen\": \"\",
                \"title\": \"Install\",
                \"url\": \"/install/${method}\",
                \"website\": \"${UMAMI_WEBSITE_ID}\",
                \"name\": \"${event_name}\",
                \"data\": {
                    \"method\": \"${method}\",
                    \"os\": \"$(uname -s 2>/dev/null || echo unknown)\",
                    \"arch\": \"$(uname -m 2>/dev/null || echo unknown)\",
                    \"shell\": \"${DETECTED_SHELL:-unknown}\",
                    \"version\": \"${version:-unknown}\"
                }
            }
        }" >/dev/null 2>&1 &)
    return 0
}

# ============================================================================
# Helpers
# ============================================================================

get_installed_version() {
    local pkg_file="${1:-$INSTALL_DIR}/package.json"
    if [[ -f "$pkg_file" ]]; then
        grep '"version"' "$pkg_file" 2>/dev/null | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//'
    fi
}

# A directory only counts as Lacy when the plugin is actually there.
is_lacy_tree() {
    [[ -f "$1/lacy.plugin.zsh" && -f "$1/lib/core/constants.sh" ]]
}

is_installed() {
    is_lacy_tree "$INSTALL_DIR"
}

# Can we ask the user anything? True when stdin is a terminal, or when a
# controlling terminal can actually be opened (curl | bash). A /dev/tty device
# node existing is not enough: Docker and CI have one but cannot open it.
_LACY_TTY=""
can_prompt() {
    if [[ -z "$_LACY_TTY" ]]; then
        _LACY_TTY="none"
        if [[ -t 0 ]]; then
            _LACY_TTY="stdin"
        elif ( exec </dev/tty ) 2>/dev/null; then
            _LACY_TTY="tty"
        fi
    fi
    [[ "$_LACY_TTY" != "none" ]]
}

# ask VAR "prompt": returns 1 without a terminal or on EOF (Ctrl+D).
ask() {
    local __var="$1" __prompt="$2" __reply=""
    can_prompt || return 1
    printf "%s" "$__prompt"
    if [[ "$_LACY_TTY" == "stdin" ]]; then
        IFS= read -r __reply || { printf "\n"; return 1; }
    else
        IFS= read -r __reply </dev/tty || { printf "\n"; return 1; }
    fi
    printf -v "$__var" '%s' "$__reply"
}

# run_with_timeout SECONDS CMD...: output discarded, 124 on timeout.
run_with_timeout() {
    local secs="$1" pid ticks=0
    shift
    "$@" >/dev/null 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if [[ $ticks -ge $((secs * 10)) ]]; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            return 124
        fi
        sleep 0.1
        ticks=$((ticks + 1))
    done
    wait "$pid"
}

is_known_tool() {
    local t
    for t in "${TOOL_LIST[@]}"; do
        [[ "$t" == "$1" ]] && return 0
    done
    return 1
}

# ============================================================================
# Shell detection
# ============================================================================

detect_user_shell() {
    if [[ -n "${LACY_FORCE_SHELL:-}" ]]; then
        DETECTED_SHELL="$LACY_FORCE_SHELL"
        return
    fi

    case "$(basename "${SHELL:-}")" in
        zsh)  DETECTED_SHELL="zsh" ;;
        bash) DETECTED_SHELL="bash" ;;
        fish) DETECTED_SHELL="fish" ;;
        *)
            if command -v zsh >/dev/null 2>&1; then
                DETECTED_SHELL="zsh"
            else
                DETECTED_SHELL="bash"
            fi
            ;;
    esac
}

get_rc_file() {
    case "$DETECTED_SHELL" in
        bash)
            # macOS terminals start login shells, which read .bash_profile
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "${HOME}/.bash_profile"
            else
                echo "${HOME}/.bashrc"
            fi
            ;;
        fish) echo "${HOME}/.config/fish/conf.d/lacy.fish" ;;
        *)    echo "${HOME}/.zshrc" ;;
    esac
}

get_plugin_file() {
    case "$DETECTED_SHELL" in
        bash) echo "lacy.plugin.bash" ;;
        fish) echo "lacy.plugin.fish" ;;
        *)    echo "lacy.plugin.zsh" ;;
    esac
}

# An uncommented line that sources a lacy plugin
rc_has_plugin() {
    [[ -f "$1" ]] && grep -Eq '^[[:space:]]*(source|\.)[[:space:]]+[^#]*lacy\.plugin\.(zsh|bash|fish)' "$1" 2>/dev/null
}

# An uncommented line that puts ~/.lacy/bin on PATH
rc_has_path() {
    [[ -f "$1" ]] && grep -Eq '^[[:space:]]*[^#[:space:]][^#]*\.lacy/bin' "$1" 2>/dev/null
}

# ============================================================================
# Node installer
# ============================================================================

use_node_installer() {
    [[ "${LACY_NO_NODE:-}" == "1" || "${LACY_FORCE_BASH:-}" == "1" ]] && return 1
    [[ -n "$MODE" || -n "$SELECTED_TOOL" ]] && return 1
    command -v npx >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 || return 1
    can_prompt
}

# Exits on success or Ctrl+C. Returns 1 to fall back to the bash installer.
run_node_installer() {
    # Offline or a slow registry must not stall the install for minutes.
    run_with_timeout 20 npm view lacy version || return 1

    local rc=0
    if [[ "$_LACY_TTY" == "tty" ]]; then
        npx --yes lacy@latest </dev/tty || rc=$?
        # @clack/prompts puts the tty in raw mode; restore it if Node did not.
        stty sane </dev/tty 2>/dev/null || true
    else
        npx --yes lacy@latest || rc=$?
        stty sane 2>/dev/null || true
    fi

    case "$rc" in
        0)   exit 0 ;;
        130) exit 130 ;;
    esac
    printf "\n"
    warn "The interactive installer failed. Continuing with the standard installer."
    printf "\n"
    return 1
}

print_banner() {
    printf "\n"
    printf "${MAGENTA}${BOLD}"
    printf "  _                      \n"
    printf " | |    __ _  ___ _   _  \n"
    printf " | |   / _\` |/ __| | | | \n"
    printf " | |__| (_| | (__| |_| | \n"
    printf " |_____\__,_|\___|\__, | \n"
    printf "                  |___/  \n"
    printf "${NC}"
    printf "${CYAN}Talk directly to your shell${NC}\n"
    printf "\n"
}

# Only failures are printed.
check_prerequisites() {
    local missing=0

    case "$DETECTED_SHELL" in
        zsh)
            if ! command -v zsh >/dev/null 2>&1; then
                error "zsh is required but was not found."
                missing=1
            fi
            ;;
        bash)
            local bash_version user_bash
            # Plain `bash` on macOS is 3.2 even when $SHELL is a newer bash
            case "${SHELL:-}" in
                */bash) user_bash="$SHELL" ;;
                *)      user_bash="bash" ;;
            esac
            bash_version=$("$user_bash" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo "0")
            if [[ "$bash_version" -lt 4 ]]; then
                error "Lacy needs bash 4 or newer (found bash ${bash_version}). Install it with: brew install bash"
                missing=1
            fi
            ;;
    esac

    if ! command -v git >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        error "git or curl is required to download Lacy."
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
}

# ============================================================================
# AI tool selection
# ============================================================================

install_lash() {
    info "Installing lash..."
    if command -v npm >/dev/null 2>&1; then
        npm install -g lashcode && return 0
    elif command -v brew >/dev/null 2>&1; then
        brew tap lacymorrow/tap && brew install lash && return 0
    else
        error "Could not install lash: npm or Homebrew is needed."
        return 1
    fi
    error "lash did not install. You can retry later with: npm install -g lashcode"
    return 1
}

# One tool installed: use it. None: offer lash. Several: ask which.
# Without a terminal nothing is asked and the default is used.
choose_tool() {
    local found=() t reply i
    for t in "${TOOL_LIST[@]}"; do
        command -v "$t" >/dev/null 2>&1 && found+=("$t")
    done

    if [[ ${#found[@]} -eq 1 ]]; then
        SELECTED_TOOL="${found[0]}"
        ok "Using ${SELECTED_TOOL}"
        return 0
    fi

    if [[ ${#found[@]} -gt 1 ]]; then
        SELECTED_TOOL="${found[0]}"
        if can_prompt; then
            printf "${BOLD}Which AI tool should Lacy use?${NC}\n"
            i=1
            for t in "${found[@]}"; do
                printf "  %d) %s\n" "$i" "$t"
                i=$((i + 1))
            done
            if ask reply "Select [1]: " && [[ "$reply" =~ ^[0-9]+$ ]] \
                && [[ "$reply" -ge 1 && "$reply" -le ${#found[@]} ]]; then
                SELECTED_TOOL="${found[$((reply - 1))]}"
            fi
        fi
        ok "Using ${SELECTED_TOOL}"
        return 0
    fi

    # Nothing installed
    if can_prompt; then
        warn "No AI CLI tool found. Lacy needs one to answer questions."
        if ! ask reply "Install lash (lash.lacy.sh)? [Y/n]: "; then
            reply="n"
        fi
        if [[ ! "$reply" =~ ^[Nn] ]] && install_lash && command -v lash >/dev/null 2>&1; then
            SELECTED_TOOL="lash"
            ok "Using lash"
            return 0
        fi
    else
        warn "No AI CLI tool found."
    fi
    printf "Install one later, for example: npm install -g lashcode\n"
    return 0
}

# ============================================================================
# Download
# ============================================================================

# Newest stable release tag (vX.Y.Z), or nothing.
latest_release_tag() {
    local url="${1:-$REPO_URL}" refs tag=""
    if command -v git >/dev/null 2>&1; then
        refs=$(git ls-remote --tags --refs --sort=-v:refname "$url" 2>/dev/null) \
            || refs=$(git ls-remote --tags --refs "$url" 2>/dev/null) \
            || refs=""
        tag=$(printf '%s\n' "$refs" \
            | sed -n 's|.*refs/tags/v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$|\1|p' \
            | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
        if [[ -n "$tag" ]]; then
            tag="v${tag}"
        fi
    fi
    if [[ -z "$tag" && -n "$TARBALL_BASE" && "$url" == "$DEFAULT_REPO_URL" ]] && command -v curl >/dev/null 2>&1; then
        tag=$(curl -fsSL --max-time 10 "https://api.github.com/repos/lacymorrow/lacy/releases/latest" 2>/dev/null \
            | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\(v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)".*/\1/p' | head -1 || true)
    fi
    printf "%s" "$tag"
}

fetch_tarball() {
    local ref="$1" dest="$2" kind="heads" tmp url
    [[ "$ref" =~ ^v[0-9] ]] && kind="tags"
    url="${TARBALL_BASE}/${kind}/${ref}.tar.gz"

    # Template must end in X's: BSD mktemp leaves "XXXXXX.tar.gz" literal.
    tmp=$(mktemp "${TMPDIR:-/tmp}/lacy-XXXXXX") || return 1

    if ! curl -fsSL --max-time 120 "$url" -o "$tmp" 2>/dev/null; then
        LAST_ERROR="could not download ${url}"
        command rm -f "$tmp"
        return 1
    fi
    # A captive portal returns HTML with status 200; make sure it is an archive.
    if ! tar tzf "$tmp" >/dev/null 2>&1; then
        LAST_ERROR="${url} is not a valid archive (captive portal or proxy?)"
        command rm -f "$tmp"
        return 1
    fi
    mkdir -p "$dest"
    if ! tar xzf "$tmp" --strip-components=1 -C "$dest" 2>/dev/null || ! is_lacy_tree "$dest"; then
        LAST_ERROR="${url} does not contain Lacy"
        command rm -f "$tmp"
        command rm -rf "$dest"
        return 1
    fi
    command rm -f "$tmp"
    return 0
}

# fetch_release REF DEST: DEST must not exist. Leaves nothing behind on failure.
fetch_release() {
    local ref="$1" dest="$2" out
    LAST_ERROR=""
    if command -v git >/dev/null 2>&1; then
        if out=$(git clone --quiet --depth 1 --branch "$ref" "$REPO_URL" "$dest" 2>&1); then
            is_lacy_tree "$dest" && return 0
            out="the download does not contain Lacy"
        elif [[ "$ref" =~ ^[0-9a-f]{7,40}$ ]]; then
            # A commit sha: clone --branch cannot take one, so fetch it directly
            command rm -rf "$dest"
            if out=$(git init --quiet "$dest" 2>&1 \
                && git -C "$dest" remote add origin "$REPO_URL" 2>&1 \
                && git -C "$dest" fetch --quiet --depth 1 origin "$ref" 2>&1 \
                && git -C "$dest" checkout --quiet FETCH_HEAD 2>&1); then
                is_lacy_tree "$dest" && return 0
                out="the download does not contain Lacy"
            fi
        fi
        command rm -rf "$dest"
        LAST_ERROR="git clone ${REPO_URL} (${ref}) failed: ${out}"
    fi
    if [[ -n "$TARBALL_BASE" ]] && command -v curl >/dev/null 2>&1; then
        local git_error="$LAST_ERROR"
        fetch_tarball "$ref" "$dest" && return 0
        [[ -n "$git_error" ]] && LAST_ERROR="${git_error}; ${LAST_ERROR}"
    fi
    [[ -n "$LAST_ERROR" ]] || LAST_ERROR="git or curl is required"
    return 1
}

# Refuse to replace a developer or Homebrew install.
refuse_unmanaged_install() {
    local action="$1" target
    if [[ -L "$INSTALL_DIR" ]]; then
        target=$(readlink "$INSTALL_DIR" 2>/dev/null || true)
        error "Not running ${action}: ~/.lacy is a symlink to ${target}."
        case "$target" in
            *"/Cellar/"*|*"/homebrew/"*)
                printf "This is a Homebrew install. Use: brew upgrade lacymorrow/tap/lacy\n" >&2 ;;
            *)
                printf "It looks like a developer checkout. Update it with git in that directory.\n" >&2 ;;
        esac
        exit 1
    fi
    if [[ -d "$INSTALL_DIR/.git" ]] && command -v git >/dev/null 2>&1; then
        if [[ -n "$(git -C "$INSTALL_DIR" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
            error "Not running ${action}: ~/.lacy has uncommitted changes."
            printf "See them with: git -C ~/.lacy status\n" >&2
            exit 1
        fi
    fi
}

# Download REF into a staging directory, then swap it in. The existing install
# is only touched after the download is verified.
install_release() {
    local ref="$1" old="" f
    STAGE_DIR="${INSTALL_DIR}.new.$$"
    command rm -rf "$STAGE_DIR"

    info "Downloading Lacy ${ref}..."
    if ! fetch_release "$ref" "$STAGE_DIR"; then
        error "Download failed: ${LAST_ERROR}"
        error "Nothing was changed."
        exit 1
    fi

    if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
        # Carry user state across
        for f in config.yaml current_mode logs .last_session .server.pid; do
            if [[ -e "$INSTALL_DIR/$f" && ! -e "$STAGE_DIR/$f" ]]; then
                cp -Rp "$INSTALL_DIR/$f" "$STAGE_DIR/$f"
            fi
        done
        old="${INSTALL_DIR}.old.$$"
        mv "$INSTALL_DIR" "$old"
    fi
    mv "$STAGE_DIR" "$INSTALL_DIR"
    STAGE_DIR=""
    [[ -n "$old" ]] && command rm -rf "$old"
    return 0
}

resolve_ref() {
    local tag
    if [[ -n "${LACY_REF:-}" ]]; then
        printf "%s" "$LACY_REF"
        return 0
    fi
    tag=$(latest_release_tag "${1:-$REPO_URL}")
    printf "%s" "${tag:-main}"
}

# ============================================================================
# Configure
# ============================================================================

configure_shell() {
    local rc_file plugin_file plugin_line path_line rc_name
    rc_file=$(get_rc_file)
    plugin_file=$(get_plugin_file)
    rc_name="~${rc_file#"$HOME"}"
    plugin_line="source ${INSTALL_DIR}/${plugin_file}"

    mkdir -p "$(dirname "$rc_file")"

    if [[ "$DETECTED_SHELL" == "fish" ]]; then
        # conf.d/lacy.fish is Lacy's own file; fish loads it automatically.
        # `>` writes through a symlink rather than replacing it.
        {
            printf "# Lacy Shell\n"
            printf "%s\n" "$plugin_line"
            printf "fish_add_path --path %s/bin\n" "$INSTALL_DIR"
        } > "$rc_file"
        ok "Configured ${rc_name}"
        return 0
    fi

    path_line="export PATH=\"${INSTALL_DIR}/bin:\$PATH\""

    if rc_has_plugin "$rc_file"; then
        if ! rc_has_path "$rc_file"; then
            printf "%s\n" "$path_line" >> "$rc_file"
        fi
        ok "Already configured in ${rc_name}"
    else
        local need_path=1
        rc_has_path "$rc_file" && need_path=0
        # Appending writes through a symlinked rc file.
        {
            printf "\n# Lacy Shell\n"
            printf "%s\n" "$plugin_line"
            if [[ $need_path -eq 1 ]]; then
                printf "%s\n" "$path_line"
            fi
        } >> "$rc_file"
        ok "Added to ${rc_name}"
    fi

    # Some macOS terminals read .bashrc as well
    if [[ "$DETECTED_SHELL" == "bash" && "$OSTYPE" == "darwin"* ]]; then
        local bashrc="${HOME}/.bashrc"
        if [[ -f "$bashrc" ]] && ! rc_has_plugin "$bashrc"; then
            {
                printf "\n# Lacy Shell\n"
                printf "%s\n" "$plugin_line"
                rc_has_path "$bashrc" || printf "%s\n" "$path_line"
            } >> "$bashrc"
            ok "Also added to ~/.bashrc"
        fi
    fi
}

_yaml_write() {
    local file="$1" key="$2" value="$3"
    local escaped_value="${value//\\/\\\\}"
    escaped_value="${escaped_value//|/\\|}"
    escaped_value="${escaped_value//&/\\&}"
    if grep -q "^[[:space:]]*${key}:" "$file" 2>/dev/null; then
        sed -i.bak "s|^\\([[:space:]]*${key}:\\).*|\\1 ${escaped_value}|" "$file"
        command rm -f "${file}.bak"
    fi
}

# Canonical default config. Same text in packages/lacy/index.mjs and
# lib/core/config.sh.
write_default_config() {
    local active="$1" custom="$2" active_line custom_line
    active_line="  active:"
    [[ -n "$active" ]] && active_line="  active: ${active}"
    custom_line='  # custom_command: "your-command --flags"'
    if [[ -n "$custom" ]]; then
        custom="${custom//\\/\\\\}"
        custom_line="  custom_command: \"${custom//\"/\\\"}\""
    fi

    cat > "$CONFIG_FILE" <<EOF
# Lacy Shell configuration
agent_tools:
  # lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, custom
  # Leave empty to auto-detect.
${active_line}
${custom_line}

modes:
  default: auto  # shell, agent, or auto

# preheat:
#   eager: false
#   server_port: 4096

# logging:
#   queries: false  # true writes ~/.lacy/logs/queries.log (owner-only)
EOF
}

# EXPLICIT=1 when the tool came from --tool (overrides an existing config).
create_config() {
    local explicit="${1:-0}" active=""
    mkdir -p "$INSTALL_DIR"
    [[ "$SELECTED_TOOL" != "auto" ]] && active="$SELECTED_TOOL"

    if [[ -f "$CONFIG_FILE" ]]; then
        if [[ "$explicit" == "1" ]]; then
            _yaml_write "$CONFIG_FILE" "active" "$active"
            if [[ "$SELECTED_TOOL" == "custom" ]]; then
                if grep -q '^[[:space:]]*custom_command:' "$CONFIG_FILE"; then
                    _yaml_write "$CONFIG_FILE" "custom_command" "\"${CUSTOM_COMMAND//\"/\\\"}\""
                else
                    printf '  custom_command: "%s"\n' "${CUSTOM_COMMAND//\"/\\\"}" > "${CONFIG_FILE}.add"
                    sed -i.bak "/^[[:space:]]*active:/r ${CONFIG_FILE}.add" "$CONFIG_FILE"
                    command rm -f "${CONFIG_FILE}.add" "${CONFIG_FILE}.bak"
                fi
            fi
        fi
        return 0
    fi

    write_default_config "$active" "$([[ "$SELECTED_TOOL" == "custom" ]] && printf '%s' "$CUSTOM_COMMAND")"
}

show_success() {
    local verb="$1" version tool_text
    version=$(get_installed_version)
    tool_text=$(sed -n 's/^[[:space:]]*active:[[:space:]]*\([^#[:space:]]*\).*/\1/p' "$CONFIG_FILE" 2>/dev/null | head -1)
    tool_text="${tool_text:-auto-detect}"

    printf "\n${GREEN}${BOLD}Lacy Shell v%s %s${NC} for %s, using %s.\n" "${version:-?}" "$verb" "$DETECTED_SHELL" "$tool_text"
    printf "Open a new terminal, then type: ${CYAN}what files are here${NC}\n"
}

# ============================================================================
# Flows
# ============================================================================

do_install() {
    local explicit=0
    [[ -n "$SELECTED_TOOL" ]] && explicit=1
    check_prerequisites
    [[ -z "$SELECTED_TOOL" && ! -f "$CONFIG_FILE" ]] && choose_tool
    install_release "$(resolve_ref)"
    configure_shell
    create_config "$explicit"
    track_event "install" "curl"
    show_success "installed"
}

do_update() {
    local explicit=0 url="$REPO_URL" ref current=""
    [[ -n "$SELECTED_TOOL" ]] && explicit=1
    check_prerequisites
    refuse_unmanaged_install "update"

    # Follow the remote the install was cloned from
    if [[ -z "${LACY_REPO_URL:-}" && -d "$INSTALL_DIR/.git" ]] && command -v git >/dev/null 2>&1; then
        url=$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || printf "%s" "$REPO_URL")
        REPO_URL="$url"
    fi
    ref=$(resolve_ref "$url")

    if [[ -d "$INSTALL_DIR/.git" ]] && command -v git >/dev/null 2>&1; then
        current=$(git -C "$INSTALL_DIR" describe --tags --exact-match HEAD 2>/dev/null || true)
    elif [[ -n "$(get_installed_version)" ]]; then
        current="v$(get_installed_version)"
    fi

    if [[ -z "${LACY_REF:-}" && "$ref" != "main" && "$current" == "$ref" ]]; then
        ok "Already on the latest release (${ref})"
    else
        install_release "$ref"
        track_event "update" "curl"
    fi
    configure_shell
    create_config "$explicit"
    show_success "is ready"
}

do_reinstall() {
    local explicit=0
    [[ -n "$SELECTED_TOOL" ]] && explicit=1
    check_prerequisites
    refuse_unmanaged_install "reinstall"
    install_release "$(resolve_ref)"
    configure_shell
    create_config "$explicit"
    show_success "reinstalled"
}

do_uninstall() {
    local script="" here tmp rc=0
    here=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)

    if [[ -f "$INSTALL_DIR/uninstall.sh" ]]; then
        script="$INSTALL_DIR/uninstall.sh"
    elif [[ -f "${HOME}/.lacy-shell/uninstall.sh" ]]; then
        script="${HOME}/.lacy-shell/uninstall.sh"
    elif [[ -n "$here" && -f "$here/uninstall.sh" ]]; then
        script="$here/uninstall.sh"
    fi

    track_event "uninstall" "curl"

    # Copy first: the script deletes the directory it lives in.
    tmp=$(mktemp "${TMPDIR:-/tmp}/lacy-uninstall-XXXXXX")
    if [[ -n "$script" ]]; then
        cp "$script" "$tmp"
    elif ! curl -fsSL --max-time 30 "https://raw.githubusercontent.com/lacymorrow/lacy/main/uninstall.sh" -o "$tmp" 2>/dev/null; then
        command rm -f "$tmp"
        error "Could not find or download uninstall.sh."
        exit 1
    fi
    bash "$tmp" || rc=$?
    command rm -f "$tmp"
    exit "$rc"
}

main() {
    detect_user_shell

    if [[ "$MODE" == "uninstall" ]]; then
        do_uninstall
    fi

    if use_node_installer; then
        run_node_installer || true
    fi

    case "$MODE" in
        update)    do_update; return ;;
        reinstall) do_reinstall; return ;;
    esac

    print_banner

    if is_installed; then
        local choice=""
        if can_prompt; then
            printf "Lacy Shell is already installed.\n\n"
            printf "  1) Update      ${DIM}move to the latest release${NC}\n"
            printf "  2) Reinstall   ${DIM}fresh copy, keeps your config${NC}\n"
            printf "  3) Uninstall\n"
            printf "  4) Cancel\n\n"
            ask choice "Select [1]: " || choice="4"
            printf "\n"
        fi
        case "${choice:-1}" in
            1) do_update ;;
            2) do_reinstall ;;
            3) do_uninstall ;;
            *) printf "Cancelled.\n" ;;
        esac
        return
    fi

    do_install
}

usage() {
    cat <<EOF
Lacy Shell installer

Usage: install.sh [options]

Options:
  --help            Show this help
  --uninstall       Remove Lacy Shell
  --update          Move an existing install to the latest release
  --reinstall       Fresh copy of the latest release (keeps config)
  --bash            Skip the Node installer
  --shell NAME      Configure zsh, bash, or fish
  --tool NAME       Use this AI tool: ${TOOL_LIST[*]}, auto
  --tool custom "CMD"
                    Use your own command

Examples:
  curl -fsSL https://lacy.sh/install | bash
  curl -fsSL https://lacy.sh/install | bash -s -- --tool claude
  curl -fsSL https://lacy.sh/install | bash -s -- --shell fish
  curl -fsSL https://lacy.sh/install | bash -s -- --uninstall
  npx lacy
EOF
}

# ============================================================================
# Arguments (any order)
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --uninstall|-u) MODE="uninstall"; shift ;;
        --update)       MODE="update"; shift ;;
        --reinstall)    MODE="reinstall"; shift ;;
        --bash)         LACY_FORCE_BASH=1; shift ;;
        --shell)
            case "${2:-}" in
                zsh|bash|fish) LACY_FORCE_SHELL="$2" ;;
                *) error "--shell needs zsh, bash, or fish"; exit 1 ;;
            esac
            shift 2
            ;;
        --tool)
            SELECTED_TOOL="${2:-}"
            if [[ "$SELECTED_TOOL" == "custom" ]]; then
                CUSTOM_COMMAND="${3:-}"
                if [[ -z "$CUSTOM_COMMAND" ]]; then
                    error "--tool custom needs a command, for example: --tool custom \"claude -p\""
                    exit 1
                fi
                shift 3
            else
                if [[ "$SELECTED_TOOL" != "auto" ]] && ! is_known_tool "$SELECTED_TOOL"; then
                    error "Unknown tool: ${SELECTED_TOOL:-(none)}. Choose one of: ${TOOL_LIST[*]}, custom, auto"
                    exit 1
                fi
                shift 2
            fi
            ;;
        *)
            error "Unknown option: $1"
            usage >&2
            exit 1
            ;;
    esac
done

main
