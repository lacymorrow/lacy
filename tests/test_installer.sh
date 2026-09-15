#!/usr/bin/env bash

# Installer, uninstaller, and CLI tests (install.sh, uninstall.sh, bin/lacy,
# packages/lacy/index.mjs).
#
# Every case runs in a throwaway HOME with a minimal PATH, no controlling
# terminal, and a local git URL. Nothing touches the real ~/.lacy, real rc
# files, the npm registry, or the network.
#
#   bash tests/test_installer.sh
#   LACY_TEST_BASH=/bin/bash bash tests/test_installer.sh   # scripts under bash 3.2
#
# LACY_REPO_URL (default file://<repo>) and LACY_REF (default: HEAD's sha) pick
# what gets installed, so CI installs the commit under test. Uncommitted
# changes to install.sh, uninstall.sh and bin/lacy are exercised directly;
# the installed tree comes from LACY_REF.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_BASH="${LACY_TEST_BASH:-$(command -v bash)}"

PASS=0
FAIL=0
SKIP=0
LAST_OUT=""
LAST_RC=0

pass() { PASS=$((PASS + 1)); printf "  ok    %s\n" "$1"; }
skip() { SKIP=$((SKIP + 1)); printf "  skip  %s (%s)\n" "$1" "$2"; }
fail() {
    FAIL=$((FAIL + 1))
    printf "  FAIL  %s\n" "$1"
    printf "%s\n" "$LAST_OUT" | tail -25 | sed 's/^/        | /'
}
check() {
    local name="$1"
    shift
    if "$@"; then pass "$name"; else fail "$name"; fi
}
has() { [[ "$LAST_OUT" == *"$1"* ]]; }
lacks() { [[ "$LAST_OUT" != *"$1"* ]]; }
count_lines() { grep -Ec "$1" "$2" 2>/dev/null || true; }

# Harness git must not pick up the developer's hooks, signing, or rewrites.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
gitq() { git -c user.name=lacy-test -c user.email=test@example.com "$@"; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/lacy-installer-test-XXXXXX")
mkdir -p "$WORK/tmp" "$WORK/sysbin" "$WORK/tools-none" "$WORK/tools-claude" "$WORK/tools-two"
SERVER_PID=""
cleanup() {
    [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null
    command rm -rf "$WORK"
}
trap cleanup EXIT

# Minimal PATH: links to the system tools the scripts need, so AI tools that
# happen to live next to git (e.g. /opt/homebrew/bin/claude) stay invisible.
for c in awk basename bash cat chmod cmp cp curl cut date dirname env grep gzip head kill ln \
         lsof mkdir mktemp mv node perl ps python3 readlink rm sed sleep sort stty tail tar \
         touch tr uname wc xargs git zsh; do
    p=$(command -v "$c" 2>/dev/null) || continue
    [[ "$p" == /* ]] && ln -sf "$p" "$WORK/sysbin/$c"
done
ln -sf "$SCRIPT_BASH" "$WORK/sysbin/bash"
[[ -e "$WORK/sysbin/zsh" ]] || { printf '#!/bin/sh\nexit 0\n' > "$WORK/sysbin/zsh"; chmod +x "$WORK/sysbin/zsh"; }
for t in claude; do printf '#!/bin/sh\nexit 0\n' > "$WORK/tools-claude/$t"; chmod +x "$WORK/tools-claude/$t"; done
for t in codex claude; do printf '#!/bin/sh\nexit 0\n' > "$WORK/tools-two/$t"; chmod +x "$WORK/tools-two/$t"; done

REPO_URL="${LACY_REPO_URL:-file://$REPO_DIR}"
REF="${LACY_REF:-$(git -C "$REPO_DIR" rev-parse HEAD)}"
TEST_PORT=$((40000 + $$ % 20000))

# Per-call knobs
TURL="$REPO_URL"   # LACY_REPO_URL
TREF="$REF"        # LACY_REF (empty: resolve the latest tag)
TTAR=""            # LACY_TARBALL_URL
TSHELL="/bin/zsh"  # SHELL
TPATH=""           # PATH

# run CMD...: no controlling terminal, stdin /dev/null, clean environment,
# 300s hang guard. Sets LAST_OUT and LAST_RC.
run() {
    LAST_OUT=$(env -i HOME="$H" PATH="$TPATH" SHELL="$TSHELL" TMPDIR="$WORK/tmp" LANG=C \
        DO_NOT_TRACK=1 LACY_NO_TELEMETRY=1 LACY_NO_NODE=1 NO_COLOR=1 \
        GIT_TERMINAL_PROMPT=0 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
        LACY_PREHEAT_SERVER_PORT="$TEST_PORT" LACY_REPO_URL="$TURL" \
        ${TREF:+LACY_REF=$TREF} ${TTAR:+LACY_TARBALL_URL=$TTAR} \
        perl -MPOSIX -e '
            if (POSIX::setsid() < 0) {
                my $pid = fork();
                if ($pid) { waitpid($pid, 0); exit($? >> 8); }
                POSIX::setsid();
            }
            alarm 300;
            exec { $ARGV[0] } @ARGV or die "exec failed: $!";
        ' "$@" </dev/null 2>&1)
    LAST_RC=$?
}

new_home() {
    H="$WORK/home-$1"
    mkdir -p "$H"
}

lacy_source_lines() { count_lines '^[[:space:]]*source .*lacy\.plugin\.' "$1"; }
lacy_any_lines() { count_lines 'lacy\.plugin|\.lacy/bin|^# Lacy Shell$' "$1"; }

echo "Testing installer (scripts run with: $("$SCRIPT_BASH" -c 'echo bash $BASH_VERSION'))"
echo "Installing $REF from $REPO_URL"
echo "================================================================"

# ----------------------------------------------------------------------------
echo "fresh install, one AI tool"
new_home fresh
TPATH="$WORK/sysbin:$WORK/tools-claude"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
FRESH_HOME="$H"
check "exits 0" [ "$LAST_RC" -eq 0 ]
check "plugin file installed" [ -f "$H/.lacy/lacy.plugin.zsh" ]
if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
    check "installed the requested commit (LACY_REF sha)" [ "$(git -C "$H/.lacy" rev-parse HEAD 2>/dev/null)" = "$REF" ]
fi
check "rc has exactly one uncommented source line" [ "$(lacy_source_lines "$H/.zshrc")" -eq 1 ]
check "rc has exactly one PATH line" [ "$(count_lines '\.lacy/bin' "$H/.zshrc")" -eq 1 ]
check "only installed tool chosen without asking" grep -qx '  active: claude' "$H/.lacy/config.yaml"
check "success message" has "Open a new terminal, then type: what files are here"
check "asks nothing" eval 'lacks "[Y/n]" && lacks "Select ["'
check "NO_COLOR: no escape codes" lacks $'\033'
check "config has no api_keys section" eval '! grep -q api_keys "$H/.lacy/config.yaml"'
BASH_CONFIG="$WORK/bash-config.yaml"
cp "$H/.lacy/config.yaml" "$BASH_CONFIG"

echo "rerun is idempotent"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "exits 0" [ "$LAST_RC" -eq 0 ]
check "still one source line" [ "$(lacy_source_lines "$H/.zshrc")" -eq 1 ]
check "still one PATH line" [ "$(count_lines '\.lacy/bin' "$H/.zshrc")" -eq 1 ]
check "reports already configured" has "Already configured"
check "no menu without a terminal" lacks "Select ["

# ----------------------------------------------------------------------------
echo "commented-out line does not count as configured"
new_home commented
printf '# source %s/.lacy/lacy.plugin.zsh\n' "$H" > "$H/.zshrc"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "exits 0" [ "$LAST_RC" -eq 0 ]
check "adds a real source line" [ "$(lacy_source_lines "$H/.zshrc")" -eq 1 ]
check "keeps the user's commented line" grep -q '^# source .*lacy.plugin.zsh' "$H/.zshrc"
check "does not claim already configured" lacks "Already configured"

# ----------------------------------------------------------------------------
echo "symlinked .zshrc survives install and uninstall"
new_home symlink
mkdir -p "$H/dotfiles"
printf 'export KEEP_ME=1\n' > "$H/dotfiles/zshrc"
cp "$H/dotfiles/zshrc" "$WORK/zshrc.orig"
ln -s "$H/dotfiles/zshrc" "$H/.zshrc"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "install exits 0" [ "$LAST_RC" -eq 0 ]
check ".zshrc is still a symlink after install" [ -L "$H/.zshrc" ]
check "line written to the symlink target" [ "$(lacy_source_lines "$H/dotfiles/zshrc")" -eq 1 ]

# A fake preheat server on the test port ("... serve --port N")
if command -v python3 >/dev/null 2>&1 && command -v lsof >/dev/null 2>&1; then
    python3 -c 'import socket, sys, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[3]))); s.listen(1); time.sleep(120)' serve --port "$TEST_PORT" &
    SERVER_PID=$!
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        [[ -n "$(lsof -tiTCP:"$TEST_PORT" -sTCP:LISTEN 2>/dev/null)" ]] && break
        sleep 0.2
    done
fi

run "$SCRIPT_BASH" "$REPO_DIR/uninstall.sh"
check "uninstall exits 0" [ "$LAST_RC" -eq 0 ]
check ".zshrc is still a symlink after uninstall" [ -L "$H/.zshrc" ]
check "symlink target back to its original bytes" cmp -s "$H/dotfiles/zshrc" "$WORK/zshrc.orig"
check "~/.lacy removed" [ ! -e "$H/.lacy" ]
if [[ -n "$SERVER_PID" ]]; then
    check "preheat server on the configured port stopped" [ -z "$(lsof -tiTCP:"$TEST_PORT" -sTCP:LISTEN 2>/dev/null)" ]
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
    SERVER_PID=""
else
    skip "preheat server stopped" "needs python3 and lsof"
fi

# ----------------------------------------------------------------------------
echo "failed clone changes nothing"
new_home badurl
printf 'export KEEP_ME=1\n' > "$H/.zshrc"
cp "$H/.zshrc" "$WORK/badurl.orig"
TURL="file://$WORK/does-not-exist"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "exits non-zero" [ "$LAST_RC" -ne 0 ]
check "no success message" eval 'lacks "Open a new terminal" && lacks "Installation complete"'
check "explains the failure" has "Download failed"
check "rc file untouched" cmp -s "$H/.zshrc" "$WORK/badurl.orig"
check "no ~/.lacy left behind" [ ! -e "$H/.lacy" ]
check "no staging directory left behind" eval '[ -z "$(ls -d "$H"/.lacy.* 2>/dev/null)" ]'

echo "captive portal archive (tarball fallback) changes nothing"
new_home portal
mkdir -p "$H/.lacy" "$WORK/portal/heads" "$WORK/good/heads"   # empty dir from an old broken run
printf 'export KEEP_ME=1\n' > "$H/.zshrc"
cp "$H/.zshrc" "$WORK/portal.orig"
printf '<html><body>Sign in to Hotel WiFi</body></html>\n' > "$WORK/portal/heads/main.tar.gz"
TREF=""
TTAR="file://$WORK/portal"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "exits non-zero" [ "$LAST_RC" -ne 0 ]
check "says the archive is invalid" has "not a valid archive"
check "no success message" lacks "Open a new terminal"
check "empty ~/.lacy is not treated as an install" lacks "already installed"
check "rc file untouched" cmp -s "$H/.zshrc" "$WORK/portal.orig"

git -C "$REPO_DIR" archive --format=tar.gz --prefix=lacy-main/ -o "$WORK/good/heads/main.tar.gz" "$REF"
TTAR="file://$WORK/good"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "valid archive installs" [ "$LAST_RC" -eq 0 ]
check "plugin file present from archive" [ -f "$H/.lacy/lacy.plugin.zsh" ]
check "rc configured once" [ "$(lacy_source_lines "$H/.zshrc")" -eq 1 ]
TURL="$REPO_URL"; TREF="$REF"; TTAR=""

# ----------------------------------------------------------------------------
echo "no terminal: nothing is asked"
new_home notools
TPATH="$WORK/sysbin:$WORK/tools-none"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "no tools: exits 0" [ "$LAST_RC" -eq 0 ]
check "no tools: no prompt" eval 'lacks "[Y/n]" && lacks "Install lash ("'
check "no tools: says so once" [ "$(printf '%s\n' "$LAST_OUT" | grep -c 'No AI CLI tool found')" -eq 1 ]
check "no tools: active left empty" grep -qx '  active:' "$H/.lacy/config.yaml"

new_home twotools
TPATH="$WORK/sysbin:$WORK/tools-two"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "two tools: exits 0" [ "$LAST_RC" -eq 0 ]
check "two tools: no menu" lacks "Select ["
check "two tools: first in recommended order" grep -qx '  active: claude' "$H/.lacy/config.yaml"

echo "--bash --tool keeps the tool"
new_home toolflag
TPATH="$WORK/sysbin:$WORK/tools-claude"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh" --bash --tool codex
check "exits 0" [ "$LAST_RC" -eq 0 ]
check "config uses codex" grep -qx '  active: codex' "$H/.lacy/config.yaml"

echo "fish"
new_home fish
TSHELL="/usr/local/bin/fish"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh" --shell fish
check "exits 0" [ "$LAST_RC" -eq 0 ]
check "uses fish_add_path" grep -q '^fish_add_path --path .*/\.lacy/bin$' "$H/.config/fish/conf.d/lacy.fish"
check "no bash export in fish config" eval '! grep -q "export PATH" "$H/.config/fish/conf.d/lacy.fish"'
run "$SCRIPT_BASH" "$REPO_DIR/uninstall.sh"
check "uninstall removes lacy.fish" [ ! -e "$H/.config/fish/conf.d/lacy.fish" ]
TSHELL="/bin/zsh"

# ----------------------------------------------------------------------------
echo "lacy doctor"
H="$FRESH_HOME"
TPATH="$WORK/sysbin:$H/.lacy/bin"
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" doctor
check "fails when the configured tool is missing" [ "$LAST_RC" -ne 0 ]
check "names the missing tool" has "Configured AI tool is not installed: claude"
TPATH="$WORK/sysbin:$WORK/tools-claude:$H/.lacy/bin"
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" doctor
check "passes when the configured tool is present" [ "$LAST_RC" -eq 0 ]
sed -i.bak 's|^source |# source |' "$H/.zshrc" && command rm -f "$H/.zshrc.bak"
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" doctor
check "fails when the rc line is commented out" eval '[ "$LAST_RC" -ne 0 ] && has "commented out"'
sed -i.bak 's|^# source |source |' "$H/.zshrc" && command rm -f "$H/.zshrc.bak"

echo "lacy reinstall and update refuse unmanaged installs"
TPATH="$WORK/sysbin:$WORK/tools-claude"
new_home devlink
cp -R "$FRESH_HOME/.lacy" "$WORK/devcheckout"
ln -s "$WORK/devcheckout" "$H/.lacy"
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" reinstall
check "reinstall exits non-zero on symlink" [ "$LAST_RC" -ne 0 ]
check "reinstall explains why" has "is a symlink"
check "symlink kept" [ -L "$H/.lacy" ]
check "checkout untouched" [ -f "$WORK/devcheckout/lacy.plugin.zsh" ]
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" update
check "update exits non-zero on symlink" eval '[ "$LAST_RC" -ne 0 ] && has "is a symlink"'

H="$FRESH_HOME"
printf '\n# local edit\n' >> "$H/.lacy/README.md"
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" reinstall
check "reinstall refuses a checkout with local changes" eval '[ "$LAST_RC" -ne 0 ] && has "uncommitted changes"'
check "local change kept" grep -q '^# local edit$' "$H/.lacy/README.md"
git -C "$H/.lacy" checkout -q -- README.md

# ----------------------------------------------------------------------------
echo "release tags and LACY_REF"
FIX="$WORK/fixture"
git clone -q --no-checkout "$REPO_URL" "$FIX"
git -C "$FIX" tag -l | while IFS= read -r t; do git -C "$FIX" tag -d "$t" >/dev/null; done
git -C "$FIX" checkout -q -B main "$REF"
git -C "$FIX" tag v9.2.0
echo released > "$FIX/RELEASE_MARKER";   git -C "$FIX" add RELEASE_MARKER;   gitq -C "$FIX" commit -qm release; git -C "$FIX" tag v9.10.0
echo prerelease > "$FIX/UNRELEASED";     git -C "$FIX" add UNRELEASED;       gitq -C "$FIX" commit -qm beta;    git -C "$FIX" tag v9.11.0-beta.1
git -C "$FIX" checkout -q -b notags v9.2.0
echo branch > "$FIX/NOTAGS_MARKER";      git -C "$FIX" add NOTAGS_MARKER;    gitq -C "$FIX" commit -qm notags
git -C "$FIX" checkout -q main

new_home tags
TURL="file://$FIX"
TREF=""
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "installs from fixture" [ "$LAST_RC" -eq 0 ]
check "latest stable tag, sorted as versions (v9.10.0 > v9.2.0)" [ -f "$H/.lacy/RELEASE_MARKER" ]
check "prerelease tags and untagged main are skipped" [ ! -e "$H/.lacy/UNRELEASED" ]

echo stable > "$FIX/NEXT_MARKER"; git -C "$FIX" add NEXT_MARKER; gitq -C "$FIX" commit -qm next; git -C "$FIX" tag v9.12.0
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" update
check "lacy update exits 0" [ "$LAST_RC" -eq 0 ]
check "lacy update moves to the newest tag" [ -f "$H/.lacy/NEXT_MARKER" ]
check "config kept across update" [ -f "$H/.lacy/config.yaml" ]
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" update
check "second update is a no-op" has "Already on the latest release (v9.12.0)"

new_home notags
TREF="notags"
run "$SCRIPT_BASH" "$REPO_DIR/install.sh"
check "LACY_REF installs a branch with no tags" eval '[ "$LAST_RC" -eq 0 ] && [ -f "$H/.lacy/NOTAGS_MARKER" ]'
TURL="$REPO_URL"; TREF="$REF"

# ----------------------------------------------------------------------------
echo "bin/lacy uninstall"
H="$FRESH_HOME"
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" uninstall
check "exits 0" [ "$LAST_RC" -eq 0 ]
check "removes rc lines" [ "$(lacy_any_lines "$H/.zshrc")" -eq 0 ]
check "removes ~/.lacy" [ ! -e "$H/.lacy" ]

# ----------------------------------------------------------------------------
echo "npm package (index.mjs)"
if command -v node >/dev/null 2>&1 && [[ -d "$REPO_DIR/packages/lacy/node_modules/@clack/prompts" ]]; then
    TPATH="$WORK/sysbin:$WORK/tools-claude"
    new_home node
    run node "$REPO_DIR/packages/lacy/index.mjs" --help
    check "--help exits 0" [ "$LAST_RC" -eq 0 ]
    run node "$REPO_DIR/packages/lacy/index.mjs" info
    check "info runs the script instead of printing it" eval 'has "Lacy Shell v" && lacks "_lacy_info_version"'
    run node "$REPO_DIR/packages/lacy/index.mjs"
    check "non-TTY install exits 0" [ "$LAST_RC" -eq 0 ]
    check "non-TTY install has no tty error" lacks "EINVAL"
    check "non-TTY install places the plugin" [ -f "$H/.lacy/lacy.plugin.zsh" ]
    check "non-TTY install writes one source line" [ "$(lacy_source_lines "$H/.zshrc")" -eq 1 ]
    check "same default config text as install.sh" cmp -s "$H/.lacy/config.yaml" "$BASH_CONFIG"
    run node "$REPO_DIR/packages/lacy/index.mjs" --uninstall
    check "non-TTY uninstall runs uninstall.sh" eval '[ "$LAST_RC" -eq 0 ] && [ ! -e "$H/.lacy" ]'
    check "non-TTY uninstall cleans rc" [ "$(lacy_any_lines "$H/.zshrc")" -eq 0 ]
else
    skip "index.mjs" "run npm ci in packages/lacy"
fi

# ----------------------------------------------------------------------------
echo "static checks"
tools_of() { printf '%s\n' "$1" | tr -d '",' | tr -s ' ' | sed 's/^ //; s/ $//'; }
core_tools=$(tools_of "$(sed -n 's/^LACY_TOOL_LIST=(\(.*\))$/\1/p' "$REPO_DIR/lib/core/constants.sh")")
check "bin/lacy tool list matches LACY_TOOL_LIST" [ "$(tools_of "$(sed -n 's/^TOOL_LIST=(\(.*\))$/\1/p' "$REPO_DIR/bin/lacy")")" = "$core_tools" ]
check "install.sh tool list matches LACY_TOOL_LIST" [ "$(tools_of "$(sed -n 's/^TOOL_LIST=(\(.*\))$/\1/p' "$REPO_DIR/install.sh")")" = "$core_tools" ]
check "index.mjs tool list matches LACY_TOOL_LIST" [ "$(tools_of "$(sed -n 's/^const TOOL_LIST = \[\(.*\)\];$/\1/p' "$REPO_DIR/packages/lacy/index.mjs")")" = "$core_tools" ]

OWNED=("$REPO_DIR/install.sh" "$REPO_DIR/uninstall.sh" "$REPO_DIR/bin/lacy" "$REPO_DIR/packages/lacy/index.mjs"
       "$REPO_DIR/packages/lacy/README.md" "$REPO_DIR/packages/lacy/package.json" "$REPO_DIR/packages/lacy/commands/info.sh")
check "no em dashes in installer files" eval '! grep -q $'"'"'\xe2\x80\x94'"'"' "${OWNED[@]}"'
check "no beta channel, nushell, or api_keys" eval '! grep -Eiq -- "--beta|LACY_CHANNEL|nushell|lacy\.plugin\.nu|api_keys" "${OWNED[@]}"'
check "no console.clear" eval '! grep -q "console.clear" "$REPO_DIR/packages/lacy/index.mjs"'
check "npm package license is FSL-1.1-MIT" grep -q '"license": "FSL-1.1-MIT"' "$REPO_DIR/packages/lacy/package.json"

TPATH="$WORK/sysbin"
H="$WORK/home-help"; mkdir -p "$H"
run "$SCRIPT_BASH" "$REPO_DIR/bin/lacy" help
check "help lists only in-shell commands that exist" eval 'has "/resume" && lacks "stop" && lacks "quit_lacy" && lacks "spinner" && lacks "lacy mode"'
run "$SCRIPT_BASH" "$REPO_DIR/install.sh" --help
check "install.sh --help lists fish and every tool" eval 'has "fish" && has "aider" && has "goose"'

echo "================================================================"
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ $FAIL -eq 0 ]]
