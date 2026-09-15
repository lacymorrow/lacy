#!/usr/bin/env bash

# Lacy Shell uninstaller
#
# This is the one uninstall implementation. `lacy uninstall`,
# `install.sh --uninstall`, and `npx lacy --uninstall` all run this script.
# It never prompts; callers ask for confirmation first if they want to.
#
# Order matters: stop the preheat server while its config and helpers still
# exist, clean rc files, then remove the install directories.

set -e

LACY_DIR="${HOME}/.lacy"
LACY_DIR_OLD="${HOME}/.lacy-shell"

if [[ -n "${NO_COLOR:-}" ]]; then
    GREEN="" YELLOW="" NC=""
else
    GREEN=$'\033[0;32m' YELLOW=$'\033[1;33m' NC=$'\033[0m'
fi

say() { printf "%s\n" "$1"; }
done_line() { printf "  %s✓%s %s\n" "$GREEN" "$NC" "$1"; }

# ----------------------------------------------------------------------------
# Preheat server
# ----------------------------------------------------------------------------

_lacy_server_port() {
    local port="${LACY_PREHEAT_SERVER_PORT:-}" cfg
    for cfg in "$LACY_DIR/config.yaml" "$LACY_DIR_OLD/config.yaml"; do
        [[ -z "$port" && -f "$cfg" ]] || continue
        port=$(grep -E '^[[:space:]]*server_port:' "$cfg" 2>/dev/null | head -1 \
            | sed -E 's/^[^:]*:[[:space:]]*//; s/[[:space:]]*#.*//; s/["'\'']//g' || true)
    done
    [[ "$port" =~ ^[0-9]+$ ]] || port=4096
    printf "%s\n" "$port"
}

# Stop a background `lash serve` / `opencode serve` left by the plugin.
# Uses the plugin's own stop routine when the core files are present, then
# checks the port directly. A PID is only signalled when its command line is
# a server on our port, so an unrelated process on the port is left alone.
stop_preheat_server() {
    local port dir pid cmdline tries
    port=$(_lacy_server_port)

    for dir in "$LACY_DIR" "$LACY_DIR_OLD"; do
        [[ -f "$dir/lib/core/constants.sh" && -f "$dir/lib/core/preheat.sh" ]] || continue
        (
            set +e
            LACY_SHELL_HOME="$dir"
            LACY_PREHEAT_SERVER_PORT="$port"
            source "$dir/lib/core/constants.sh"
            source "$dir/lib/core/preheat.sh"
            if declare -F lacy_preheat_server_stop >/dev/null; then
                lacy_preheat_server_stop
            fi
        ) >/dev/null 2>&1 </dev/null || true
    done

    command -v lsof >/dev/null 2>&1 || return 0
    for pid in $(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true); do
        cmdline=$(ps -o command= -p "$pid" 2>/dev/null || true)
        case "$cmdline" in
            *"serve --port ${port}"|*"serve --port ${port} "*) ;;
            *) continue ;;
        esac
        kill -TERM "$pid" 2>/dev/null || true
        tries=0
        while kill -0 "$pid" 2>/dev/null && [[ $tries -lt 20 ]]; do
            sleep 0.1
            tries=$((tries + 1))
        done
        kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
        done_line "Stopped background server on port ${port}"
    done
}

# ----------------------------------------------------------------------------
# rc files
# ----------------------------------------------------------------------------

# Drop the lines the installer writes ("# Lacy Shell", the lacy.plugin source
# line, the ~/.lacy/bin PATH line) plus the blank line placed before them.
_lacy_strip_rc_lines() {
    awk '
        function is_lacy(l) {
            return l == "# Lacy Shell" || l ~ /lacy\.plugin\.(zsh|bash|fish)/ || l ~ /\.lacy\/bin/
        }
        is_lacy($0) { held = 0; next }
        {
            if (held) { print blank; held = 0 }
            if ($0 ~ /^[ \t]*$/) { blank = $0; held = 1; next }
            print
        }
        END { if (held) print blank }
    '
}

remove_from_file() {
    local file="$1" tmp
    [[ -f "$file" ]] || return 0
    grep -Eq 'lacy\.plugin\.(zsh|bash|fish)|\.lacy/bin|^# Lacy Shell$' "$file" 2>/dev/null || return 0

    tmp=$(mktemp "${TMPDIR:-/tmp}/lacy-rc-XXXXXX")
    _lacy_strip_rc_lines < "$file" > "$tmp"
    # Write through the path (not mv) so a symlinked rc file stays a symlink.
    cat "$tmp" > "$file"
    command rm -f "$tmp"
    done_line "Removed from ~${file#"$HOME"}"
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

RC_FILES=(
    "${HOME}/.zshrc"
    "${HOME}/.bashrc"
    "${HOME}/.bash_profile"
    "${HOME}/.config/fish/conf.d/lacy.fish"
)

has_rc_lines=0
for rc in "${RC_FILES[@]}"; do
    if [[ -f "$rc" ]] && grep -Eq 'lacy\.plugin\.(zsh|bash|fish)|\.lacy/bin' "$rc" 2>/dev/null; then
        has_rc_lines=1
    fi
done

if [[ ! -e "$LACY_DIR" && ! -L "$LACY_DIR" && ! -e "$LACY_DIR_OLD" && $has_rc_lines -eq 0 ]]; then
    say "Lacy Shell is not installed."
    exit 0
fi

say "Uninstalling Lacy Shell..."

stop_preheat_server

for rc in "${RC_FILES[@]}"; do
    remove_from_file "$rc"
done

# conf.d/lacy.fish belongs to Lacy; delete it once it holds nothing else.
fish_conf="${HOME}/.config/fish/conf.d/lacy.fish"
if [[ -f "$fish_conf" && ! -L "$fish_conf" ]] && ! grep -q '[^[:space:]]' "$fish_conf" 2>/dev/null; then
    command rm -f "$fish_conf"
fi

# Homebrew installs link ~/.lacy into the Cellar
is_brew=0
if [[ -L "$LACY_DIR" ]]; then
    link_target=$(readlink "$LACY_DIR" 2>/dev/null || true)
    case "$link_target" in
        *"/Cellar/"*|*"/homebrew/"*) is_brew=1 ;;
    esac
    # Only the link goes; a developer checkout it points to is left untouched.
    command rm -f "$LACY_DIR"
    done_line "Removed ~/.lacy symlink (target left in place: ${link_target})"
elif [[ -d "$LACY_DIR" ]]; then
    command rm -rf "$LACY_DIR"
    done_line "Removed ~/.lacy"
fi

if [[ -d "$LACY_DIR_OLD" ]]; then
    command rm -rf "$LACY_DIR_OLD"
    done_line "Removed ~/.lacy-shell"
fi

if [[ $is_brew -eq 1 ]] && command -v brew >/dev/null 2>&1; then
    if brew uninstall lacymorrow/tap/lacy >/dev/null 2>&1; then
        done_line "Removed Homebrew formula"
    else
        printf "  %s!%s Run: brew uninstall lacymorrow/tap/lacy\n" "$YELLOW" "$NC"
    fi
fi

say ""
say "Lacy Shell uninstalled. Open a new terminal to finish."
