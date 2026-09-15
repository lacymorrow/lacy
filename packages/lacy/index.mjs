#!/usr/bin/env node

import * as p from "@clack/prompts";
import pc from "picocolors";
import { execFileSync, execSync, spawn, spawnSync } from "child_process";
import {
  appendFileSync,
  copyFileSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "fs";
import { homedir, tmpdir } from "os";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const INSTALL_DIR = join(homedir(), ".lacy");
const INSTALL_DIR_OLD = join(homedir(), ".lacy-shell");
const CONFIG_FILE = join(INSTALL_DIR, "config.yaml");
const DEFAULT_REPO_URL = "https://github.com/lacymorrow/lacy.git";
// LACY_REPO_URL and LACY_REF let tests and CI install a local checkout.
const REPO_URL = process.env.LACY_REPO_URL || DEFAULT_REPO_URL;
const TARBALL_BASE =
  process.env.LACY_TARBALL_URL ||
  (REPO_URL === DEFAULT_REPO_URL
    ? "https://github.com/lacymorrow/lacy/archive/refs"
    : "");
const GIT_ENV = { ...process.env, GIT_TERMINAL_PROMPT: "0" };

// User state carried across a reinstall
const STATE_FILES = ["config.yaml", "current_mode", "logs", ".last_session", ".server.pid"];

// Keep in sync with LACY_TOOL_LIST in lib/core/constants.sh (tests check).
const TOOL_LIST = ["lash", "claude", "opencode", "gemini", "codex", "hermes", "copilot", "goose", "amp", "aider"];

const TOOL_HINTS = {
  lash: "AI coding agent, lash.lacy.sh (recommended)",
  claude: "Claude Code CLI",
  opencode: "OpenCode CLI",
  gemini: "Google Gemini CLI",
  codex: "OpenAI Codex CLI",
  hermes: "Hermes Agent by Nous Research",
  copilot: "GitHub Copilot CLI",
  goose: "Goose agent by Block",
  amp: "Sourcegraph Amp CLI",
  aider: "Aider pair programming",
};

const MODES = [
  { value: "auto", label: "Auto", hint: "smart detection (recommended)" },
  { value: "shell", label: "Shell", hint: "all commands execute directly" },
  { value: "agent", label: "Agent", hint: "all input goes to AI" },
];

// An uncommented line that sources a lacy plugin / puts ~/.lacy/bin on PATH
const PLUGIN_LINE_RE = /^[ \t]*(source|\.)[ \t]+[^#\n]*lacy\.plugin\.(zsh|bash|fish)/m;
const PATH_LINE_RE = /^[ \t]*[^#\s][^#\n]*\.lacy\/bin/m;

// Version: read from installed package.json (single source of truth),
// fall back to this npm package's own package.json
function getVersion() {
  for (const dir of [INSTALL_DIR, INSTALL_DIR_OLD, __dirname]) {
    const pkgPath = join(dir, "package.json");
    if (existsSync(pkgPath)) {
      try {
        const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
        if (pkg.version) return pkg.version;
      } catch {}
    }
  }
  return "unknown";
}

const VERSION = getVersion();

function isInteractive() {
  return Boolean(process.stdin.isTTY && process.stdout.isTTY);
}

// ============================================================================
// Terminal state safety net
// ============================================================================
// @clack/prompts puts stdin into raw mode during prompts. If the process exits
// abnormally, raw mode is never restored and the parent shell's tty is left
// broken until a new window is opened. These handlers always clean up.

function restoreTerminalState() {
  try {
    if (process.stdin.isTTY && process.stdin.isRaw) {
      process.stdin.setRawMode(false);
    }
  } catch {
    // stdin may already be destroyed
  }
  if (process.stdout.isTTY) {
    // Restore cursor visibility and line wrapping
    process.stdout.write("\x1b[?25h\x1b[?7h");
  }
}

process.on("exit", restoreTerminalState);

for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => {
    restoreTerminalState();
    process.exit(128 + { SIGINT: 2, SIGTERM: 15, SIGHUP: 1 }[signal]);
  });
}

// Ctrl+C / Escape at a prompt. 130 tells the calling shell script to stop
// instead of falling back to the bash installer.
function cancelled(message) {
  p.cancel(message);
  process.exit(130);
}

// Spinners redraw with escape codes; without a terminal, log plain lines.
function spinner() {
  if (isInteractive()) return p.spinner();
  return {
    start: (msg) => p.log.step(msg),
    stop: (msg) => p.log.success(msg),
    message: () => {},
  };
}

// ============================================================================
// Shell detection
// ============================================================================

function detectShell() {
  const base = (process.env.SHELL || "").split("/").pop();
  if (base === "bash" || base === "zsh" || base === "fish") return base;
  return commandExists("zsh") ? "zsh" : "bash";
}

function getShellConfig(shell) {
  const home = homedir();
  switch (shell) {
    case "bash":
      return {
        shell,
        rcFile: process.platform === "darwin" ? join(home, ".bash_profile") : join(home, ".bashrc"),
        extraRcFile: process.platform === "darwin" ? join(home, ".bashrc") : null,
        pluginFile: "lacy.plugin.bash",
        shellCmd: "bash",
        rcName: process.platform === "darwin" ? ".bash_profile" : ".bashrc",
      };
    case "fish":
      return {
        shell,
        rcFile: join(home, ".config", "fish", "conf.d", "lacy.fish"),
        extraRcFile: null,
        pluginFile: "lacy.plugin.fish",
        shellCmd: "fish",
        rcName: "conf.d/lacy.fish",
      };
    default:
      return {
        shell: "zsh",
        rcFile: join(home, ".zshrc"),
        extraRcFile: null,
        pluginFile: "lacy.plugin.zsh",
        shellCmd: "zsh",
        rcName: ".zshrc",
      };
  }
}

// ============================================================================
// Analytics: anonymous install counts via Umami. No PII. Respects DO_NOT_TRACK.
// ============================================================================

const UMAMI_URL = process.env.LACY_UMAMI_URL || "https://analytics.lacy.sh";
const UMAMI_WEBSITE_ID = process.env.LACY_UMAMI_WEBSITE_ID || "577521d7-3db7-4a77-a45c-3c97f21b5322";

// Resolves within 2 seconds either way, so callers can await it before exiting.
function trackEvent(eventName, method = "npx") {
  if (process.env.DO_NOT_TRACK === "1" || process.env.LACY_NO_TELEMETRY === "1") {
    return Promise.resolve();
  }

  const version = getVersion();
  const send = fetch(`${UMAMI_URL}/api/send`, {
    method: "POST",
    signal: AbortSignal.timeout(2000),
    headers: {
      "Content-Type": "application/json",
      "User-Agent": `lacy-install/${version}`,
    },
    body: JSON.stringify({
      type: "event",
      payload: {
        hostname: "lacy.sh",
        language: "",
        referrer: "",
        screen: "",
        title: "Install",
        url: `/install/${method}`,
        website: UMAMI_WEBSITE_ID,
        name: eventName,
        data: {
          method,
          os: process.platform,
          arch: process.arch,
          shell: detectShell(),
          version,
        },
      },
    }),
  }).catch(() => {});
  return Promise.race([send, new Promise((r) => setTimeout(r, 2000))]);
}

// ============================================================================
// Helpers
// ============================================================================

function commandExists(cmd) {
  if (!/^[a-zA-Z0-9._-]+$/.test(cmd)) return false;
  try {
    execSync(`command -v ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function pathExists(path) {
  try {
    lstatSync(path);
    return true;
  } catch {
    return false;
  }
}

function isLacyTree(dir) {
  return existsSync(join(dir, "lacy.plugin.zsh")) && existsSync(join(dir, "lib", "core", "constants.sh"));
}

// A directory only counts as an install when the plugin is actually there.
function isInstalled() {
  return isLacyTree(INSTALL_DIR) || isLacyTree(INSTALL_DIR_OLD);
}

function detectTools() {
  return TOOL_LIST.filter((tool) => commandExists(tool));
}

function readConfigValue(key) {
  if (!existsSync(CONFIG_FILE)) return "";
  const content = readFileSync(CONFIG_FILE, "utf-8");
  const match = content.match(new RegExp(`^[ \\t]*${key}:[ \\t]*(.*)$`, "m"));
  if (!match) return "";
  return match[1].replace(/(^|[ \t])#.*$/, "").replace(/["']/g, "").trim();
}

function writeConfigValue(key, value) {
  if (!existsSync(CONFIG_FILE)) return;
  const content = readFileSync(CONFIG_FILE, "utf-8");
  // [ \t], not \s: \s would run past the newline and eat the next line
  const regex = new RegExp(`^([ \\t]*${key}:)[ \\t]*.*$`, "m");
  if (regex.test(content)) {
    writeFileSync(CONFIG_FILE, content.replace(regex, (_, lead) => (value ? `${lead} ${value}` : lead)));
  }
}

// Canonical default config. Same text in install.sh and lib/core/config.sh.
function defaultConfig(active = "", customCommand = "") {
  const activeLine = active ? `  active: ${active}` : "  active:";
  const customLine = customCommand
    ? `  custom_command: "${customCommand.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`
    : '  # custom_command: "your-command --flags"';
  return `# Lacy Shell configuration
agent_tools:
  # lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, custom
  # Leave empty to auto-detect.
${activeLine}
${customLine}

modes:
  default: auto  # shell, agent, or auto

# preheat:
#   eager: false
#   server_port: 4096

# logging:
#   queries: false  # true writes ~/.lacy/logs/queries.log (owner-only)
`;
}

// Run install.sh or uninstall.sh from ~/.lacy. A temp copy is used because
// both scripts replace or delete the directory they live in.
// Returns the exit status, or null when the script is not there.
function runRepoScript(name, args = []) {
  const src = [INSTALL_DIR, INSTALL_DIR_OLD].map((d) => join(d, name)).find((f) => existsSync(f));
  if (!src) return null;
  const tmp = mkdtempSync(join(tmpdir(), "lacy-"));
  const copy = join(tmp, name);
  copyFileSync(src, copy);
  restoreTerminalState();
  const result = spawnSync("bash", [copy, ...args], {
    stdio: "inherit",
    env: { ...process.env, LACY_NO_NODE: "1" },
  });
  rmSync(tmp, { recursive: true, force: true });
  return result.status ?? 1;
}

// ============================================================================
// Download
// ============================================================================

// LACY_REF, else the newest stable release tag, else main.
async function resolveRef() {
  if (process.env.LACY_REF) return process.env.LACY_REF;

  if (commandExists("git")) {
    try {
      const out = execFileSync("git", ["ls-remote", "--tags", "--refs", REPO_URL], {
        env: GIT_ENV,
        stdio: ["ignore", "pipe", "ignore"],
        timeout: 20000,
      }).toString();
      const tags = [...out.matchAll(/refs\/tags\/v(\d+)\.(\d+)\.(\d+)$/gm)].map((m) => [+m[1], +m[2], +m[3]]);
      tags.sort((a, b) => b[0] - a[0] || b[1] - a[1] || b[2] - a[2]);
      if (tags.length > 0) return `v${tags[0].join(".")}`;
    } catch {}
  }

  if (REPO_URL === DEFAULT_REPO_URL) {
    try {
      const res = await fetch("https://api.github.com/repos/lacymorrow/lacy/releases/latest", {
        signal: AbortSignal.timeout(10000),
      });
      const json = await res.json();
      if (/^v\d+\.\d+\.\d+$/.test(json.tag_name || "")) return json.tag_name;
    } catch {}
  }

  return "main";
}

function stderrOf(e) {
  return (e.stderr ? e.stderr.toString() : e.message || "").trim();
}

// Fetch REF into DEST (which must not exist). Throws with the reason on failure.
function fetchRelease(ref, dest) {
  const errors = [];
  const gitOpts = { env: GIT_ENV, stdio: ["ignore", "ignore", "pipe"], timeout: 300000 };

  if (commandExists("git")) {
    try {
      execFileSync("git", ["clone", "--quiet", "--depth", "1", "--branch", ref, REPO_URL, dest], gitOpts);
      if (isLacyTree(dest)) return;
      errors.push("the download does not contain Lacy");
    } catch (e) {
      rmSync(dest, { recursive: true, force: true });
      if (/^[0-9a-f]{7,40}$/.test(ref)) {
        // A commit sha: clone --branch cannot take one
        try {
          execFileSync("git", ["init", "--quiet", dest], gitOpts);
          execFileSync("git", ["-C", dest, "remote", "add", "origin", REPO_URL], gitOpts);
          execFileSync("git", ["-C", dest, "fetch", "--quiet", "--depth", "1", "origin", ref], gitOpts);
          execFileSync("git", ["-C", dest, "checkout", "--quiet", "FETCH_HEAD"], gitOpts);
          if (isLacyTree(dest)) return;
          errors.push("the download does not contain Lacy");
        } catch (e2) {
          errors.push(`git fetch ${REPO_URL} ${ref} failed: ${stderrOf(e2)}`);
        }
      } else {
        errors.push(`git clone ${REPO_URL} (${ref}) failed: ${stderrOf(e)}`);
      }
    }
    rmSync(dest, { recursive: true, force: true });
  }

  if (TARBALL_BASE && commandExists("curl")) {
    const kind = /^v\d/.test(ref) ? "tags" : "heads";
    const url = `${TARBALL_BASE}/${kind}/${ref}.tar.gz`;
    const tmp = mkdtempSync(join(tmpdir(), "lacy-"));
    const file = join(tmp, "lacy.tar.gz");
    try {
      execFileSync("curl", ["-fsSL", "--max-time", "120", url, "-o", file], { stdio: "ignore" });
      // A captive portal answers with HTML; make sure this is an archive
      execFileSync("tar", ["tzf", file], { stdio: "ignore" });
      mkdirSync(dest, { recursive: true });
      execFileSync("tar", ["xzf", file, "--strip-components=1", "-C", dest], { stdio: "ignore" });
      if (isLacyTree(dest)) return;
      errors.push(`${url} does not contain Lacy`);
    } catch {
      errors.push(`could not download a valid archive from ${url}`);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
    rmSync(dest, { recursive: true, force: true });
  }

  throw new Error(errors.join("; ") || "git or curl is required to download Lacy");
}

// Move a verified download into place, keeping user state.
function swapIn(stage) {
  let old = null;
  if (pathExists(INSTALL_DIR)) {
    for (const name of STATE_FILES) {
      const src = join(INSTALL_DIR, name);
      const dst = join(stage, name);
      if (existsSync(src) && !existsSync(dst)) cpSync(src, dst, { recursive: true });
    }
    old = `${INSTALL_DIR}.old.${process.pid}`;
    renameSync(INSTALL_DIR, old);
  }
  renameSync(stage, INSTALL_DIR);
  if (old) rmSync(old, { recursive: true, force: true });
}

// ============================================================================
// Shell restart (settings changes only; install never asks)
// ============================================================================

async function restartShell(message = "Restart shell now to apply changes?", shellCmd = null) {
  if (!isInteractive()) return;

  const restart = await p.confirm({ message, initialValue: true });
  if (p.isCancel(restart) || !restart) return;

  const cmd = shellCmd || getShellConfig(detectShell()).shellCmd;
  p.log.info(`Restarting ${cmd}...`);
  restoreTerminalState();

  // Ctrl+C in the child shell must not kill Node; Node just waits for it.
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) {
    process.removeAllListeners(sig);
  }
  process.on("SIGINT", () => {});

  // spawn, not execSync("exec ..."): exec would only replace the child and
  // leave the user in a nested shell with a broken terminal.
  const child = spawn(cmd, ["-l"], { stdio: "inherit", detached: false });
  child.on("error", () => {
    p.log.warn(`Could not restart. Please run: exec ${cmd} -l`);
    process.exit(0);
  });
  child.on("exit", (code) => process.exit(code ?? 0));
  return new Promise(() => {});
}

// ============================================================================
// Uninstall: the work is done by uninstall.sh
// ============================================================================

async function uninstall({ askConfirm = true } = {}) {
  const anything = pathExists(INSTALL_DIR) || existsSync(INSTALL_DIR_OLD);

  if (isInteractive()) {
    p.intro(pc.magenta(pc.bold("  Lacy Shell  ")) + pc.dim(` v${VERSION}`));
    if (!anything) {
      p.log.warn("Lacy Shell is not installed");
      p.outro("Nothing to uninstall");
      return;
    }
    if (askConfirm) {
      const confirm = await p.confirm({ message: "Uninstall Lacy Shell?", initialValue: false });
      if (p.isCancel(confirm)) cancelled("Uninstall cancelled");
      if (!confirm) {
        p.outro("Uninstall cancelled");
        return;
      }
    }
  } else if (!anything) {
    console.log("Lacy Shell is not installed.");
    return;
  }

  await trackEvent("uninstall");
  const status = runRepoScript("uninstall.sh");
  if (status === null) {
    console.error("uninstall.sh was not found in ~/.lacy. Run: curl -fsSL https://lacy.sh/install | bash -s -- --uninstall");
    process.exit(1);
  }
  process.exit(status);
}

// ============================================================================
// Install
// ============================================================================

function checkPrerequisites(shell) {
  const missing = [];
  if (shell === "bash") {
    const shellEnv = process.env.SHELL || "";
    // Plain `bash` on macOS is 3.2 even when $SHELL is a newer bash
    const userBash = shellEnv.endsWith("/bash") ? shellEnv : "bash";
    let major = 0;
    try {
      major = parseInt(execFileSync(userBash, ["-c", "echo ${BASH_VERSINFO[0]}"], { stdio: "pipe" }).toString(), 10);
    } catch {}
    if (!(major >= 4)) missing.push(`bash 4+ (found ${major || "none"}; brew install bash)`);
  } else if (shell === "zsh" && !commandExists("zsh")) {
    missing.push("zsh");
  }
  if (!commandExists("git") && !commandExists("curl")) missing.push("git or curl");
  return missing;
}

function installLash() {
  const s = spinner();
  s.start("Installing lash");
  try {
    if (commandExists("npm")) {
      execSync("npm install -g lashcode", { stdio: "pipe" });
    } else if (commandExists("brew")) {
      execSync("brew tap lacymorrow/tap && brew install lash", { stdio: "pipe" });
    } else {
      s.stop("Could not install lash: npm or Homebrew is needed");
      return false;
    }
  } catch {
    s.stop("lash did not install");
    return false;
  }
  s.stop("lash installed");
  return commandExists("lash");
}

// One tool installed: use it. None: offer lash. Several: ask which.
// Without a terminal nothing is asked and the default is used.
async function chooseTool() {
  const detected = detectTools();

  if (detected.length === 1 || (detected.length > 1 && !isInteractive())) {
    p.log.info(`Using ${pc.green(detected[0])}`);
    return detected[0];
  }

  if (detected.length > 1) {
    const choice = await p.select({
      message: "Which AI tool should Lacy use?",
      options: detected.map((t) => ({ value: t, label: t, hint: TOOL_HINTS[t] })),
      initialValue: detected[0],
    });
    if (p.isCancel(choice)) cancelled("Installation cancelled");
    return choice;
  }

  if (!isInteractive()) {
    p.log.warn("No AI CLI tool found. Install one later, for example: npm install -g lashcode");
    return "";
  }

  p.log.warn("No AI CLI tool found. Lacy needs one to answer questions.");
  const yes = await p.confirm({
    message: `Install ${pc.green("lash")} (lash.lacy.sh)?`,
    initialValue: true,
  });
  if (p.isCancel(yes)) cancelled("Installation cancelled");
  if (yes && installLash()) return "lash";
  p.log.info("Install one later, for example: npm install -g lashcode");
  return "";
}

function appendLacyBlock(file, sourceLine, pathLine, content) {
  const needPath = !PATH_LINE_RE.test(content);
  appendFileSync(file, `\n# Lacy Shell\n${sourceLine}\n${needPath ? `${pathLine}\n` : ""}`);
}

// Returns a one-line summary. Appending and writing both go through symlinks.
function configureShell({ shell, rcFile, extraRcFile, pluginFile, rcName }) {
  const sourceLine = `source ${INSTALL_DIR}/${pluginFile}`;
  mkdirSync(dirname(rcFile), { recursive: true });

  if (shell === "fish") {
    // conf.d/lacy.fish is Lacy's own file
    writeFileSync(rcFile, `# Lacy Shell\n${sourceLine}\nfish_add_path --path ${INSTALL_DIR}/bin\n`);
    return `Configured ${rcName}`;
  }

  const pathLine = `export PATH="${INSTALL_DIR}/bin:$PATH"`;
  const content = existsSync(rcFile) ? readFileSync(rcFile, "utf-8") : "";
  let summary;

  if (PLUGIN_LINE_RE.test(content)) {
    if (!PATH_LINE_RE.test(content)) appendFileSync(rcFile, `${pathLine}\n`);
    summary = `Already configured in ${rcName}`;
  } else {
    appendLacyBlock(rcFile, sourceLine, pathLine, content);
    summary = `Added to ${rcName}`;
  }

  if (extraRcFile && existsSync(extraRcFile)) {
    const extra = readFileSync(extraRcFile, "utf-8");
    if (!PLUGIN_LINE_RE.test(extra)) appendLacyBlock(extraRcFile, sourceLine, pathLine, extra);
  }

  return summary;
}

async function install() {
  p.intro(pc.magenta(pc.bold("  Lacy Shell  ")) + pc.dim(` v${VERSION}`));

  const shell = detectShell();
  const shellConfig = getShellConfig(shell);

  const missing = checkPrerequisites(shell);
  if (missing.length > 0) {
    p.log.error(`Missing: ${missing.join(", ")}`);
    p.outro(pc.red("Install the missing tools and try again."));
    process.exit(1);
  }

  const selectedTool = existsSync(CONFIG_FILE) ? null : await chooseTool();

  const ref = await resolveRef();
  const download = spinner();
  download.start(`Downloading Lacy ${ref}`);
  const stage = `${INSTALL_DIR}.new.${process.pid}`;
  rmSync(stage, { recursive: true, force: true });
  try {
    fetchRelease(ref, stage);
    swapIn(stage);
  } catch (e) {
    rmSync(stage, { recursive: true, force: true });
    download.stop("Download failed");
    p.log.error(e.message);
    p.outro(pc.red("Nothing was changed."));
    process.exit(1);
  }
  download.stop(`Downloaded Lacy ${ref}`);

  p.log.success(configureShell(shellConfig));

  if (!existsSync(CONFIG_FILE)) {
    writeFileSync(CONFIG_FILE, defaultConfig(selectedTool || ""));
  }

  await trackEvent("install");

  const tool = readConfigValue("active") || "auto-detect";
  p.log.success(`Lacy Shell v${getVersion()} installed for ${shell}, using ${tool}.`);
  p.outro(`Open a new terminal, then type: ${pc.cyan("what files are here")}`);
}

// ============================================================================
// Settings dashboard (already installed)
// ============================================================================

async function dashboard() {
  p.intro(pc.magenta(pc.bold("  Lacy Shell  ")) + pc.dim(` v${VERSION}`));

  const active = readConfigValue("active");
  const mode = readConfigValue("default") || "auto";
  const detected = detectTools();
  const toolsDisplay = detected.length > 0 ? detected.map((t) => pc.green(t)).join(", ") : pc.yellow("none");

  p.note(
    `  Tool:       ${pc.cyan(active || "auto-detect")}
  Mode:       ${pc.cyan(mode)}
  Installed:  ${toolsDisplay}`,
    "Current config",
  );

  while (true) {
    const action = await p.select({
      message: "What would you like to do?",
      options: [
        { value: "tool", label: "Change AI tool", hint: `current: ${active || "auto-detect"}` },
        { value: "mode", label: "Change mode", hint: `current: ${mode}` },
        { value: "config", label: "Edit config", hint: "open in $EDITOR" },
        { value: "status", label: "Status", hint: "show full installation info" },
        { value: "update", label: "Update", hint: "move to the latest release" },
        { value: "reinstall", label: "Reinstall", hint: "fresh copy, keeps your config" },
        { value: "uninstall", label: "Uninstall", hint: "remove Lacy Shell" },
        { value: "done", label: "Done" },
      ],
    });

    if (p.isCancel(action) || action === "done") break;

    if (action === "tool") {
      const selectedTool = await p.select({
        message: "Which AI CLI tool do you want to use?",
        options: [
          ...TOOL_LIST.map((t) => ({
            value: t,
            label: t,
            hint: detected.includes(t) ? pc.green("installed") : TOOL_HINTS[t],
          })),
          { value: "custom", label: "Custom", hint: "enter your own command" },
          { value: "auto", label: "Auto-detect", hint: "use the first one installed" },
        ],
        initialValue: active || detected[0] || "auto",
      });
      if (p.isCancel(selectedTool)) continue;

      if (selectedTool === "custom") {
        const customCmd = await p.text({
          message: "Enter your custom command (query will be appended as a quoted argument):",
          placeholder: "claude --dangerously-skip-permissions -p",
          validate(value) {
            if (!value || value.trim().length === 0) return "Command cannot be empty";
          },
        });
        if (p.isCancel(customCmd)) continue;
        writeConfigValue("active", "custom");
        if (readFileSync(CONFIG_FILE, "utf-8").match(/^[ \t]*custom_command:/m)) {
          writeConfigValue("custom_command", `"${customCmd}"`);
        } else {
          writeFileSync(
            CONFIG_FILE,
            readFileSync(CONFIG_FILE, "utf-8").replace(/^([ \t]*active:.*)$/m, (line) => `${line}\n  custom_command: "${customCmd}"`),
          );
        }
        p.log.success(`Tool set to: ${pc.cyan("custom")} (${customCmd})`);
      } else if (selectedTool === "auto") {
        writeConfigValue("active", "");
        p.log.success(`Tool set to: ${pc.cyan("auto-detect")}`);
      } else {
        writeConfigValue("active", selectedTool);
        p.log.success(`Tool set to: ${pc.cyan(selectedTool)}`);
      }

      await restartShell();
      break;
    }

    if (action === "mode") {
      const selectedMode = await p.select({
        message: "Which default mode?",
        options: MODES,
        initialValue: mode,
      });
      if (p.isCancel(selectedMode)) continue;

      writeConfigValue("default", `${selectedMode}  # shell, agent, or auto`);
      p.log.success(`Mode set to: ${pc.cyan(selectedMode)}`);

      await restartShell();
      break;
    }

    if (action === "config") {
      const editor = process.env.EDITOR || process.env.VISUAL || "vi";
      p.log.info(`Opening ${pc.cyan(CONFIG_FILE)} in ${editor}...`);
      try {
        execSync(`${editor} "${CONFIG_FILE}"`, { stdio: "inherit" });
      } catch {
        p.log.warn("Editor closed");
      }

      await restartShell();
      break;
    }

    if (action === "status") {
      const dir = isLacyTree(INSTALL_DIR) ? INSTALL_DIR : INSTALL_DIR_OLD;
      let ref = "";
      try {
        ref = execFileSync("git", ["describe", "--tags", "--always"], { cwd: dir, stdio: "pipe" }).toString().trim();
      } catch {}

      const shell = detectShell();
      const rc = getShellConfig(shell).rcFile;
      const rcConfigured = existsSync(rc) && PLUGIN_LINE_RE.test(readFileSync(rc, "utf-8"));

      const lines = [
        `  Installed:  ${pc.green(dir)}`,
        `  Version:    ${pc.cyan("v" + VERSION)}${ref ? pc.dim(` (${ref})`) : ""}`,
        `  Shell:      ${pc.cyan(shell)} ${rcConfigured ? pc.green("configured") : pc.yellow("not configured")}`,
        `  Config:     ${existsSync(CONFIG_FILE) ? pc.green("exists") : pc.yellow("missing")}`,
        `  Tool:       ${pc.cyan(active || "auto-detect")}`,
        `  Mode:       ${pc.cyan(mode)}`,
        ``,
        `  ${pc.bold("AI CLI tools:")}`,
        ...TOOL_LIST.map((t) => (commandExists(t) ? `    ${pc.green("✓")} ${t}` : `    ${pc.dim("○")} ${pc.dim(t)}`)),
      ];

      p.note(lines.join("\n"), "Status");
      continue;
    }

    if (action === "uninstall") {
      await uninstall();
      return;
    }

    if (action === "update" || action === "reinstall") {
      const status = runRepoScript("install.sh", [`--${action}`]);
      if (status === null) {
        p.log.error("install.sh was not found in ~/.lacy. Run: curl -fsSL https://lacy.sh/install | bash");
        process.exit(1);
      }
      process.exit(status);
    }
  }

  p.outro(pc.dim("https://github.com/lacymorrow/lacy"));
}

// ============================================================================
// Main
// ============================================================================

function printHelp() {
  console.log(`
${pc.magenta(pc.bold("Lacy Shell"))} ${pc.dim(`v${VERSION}`)}: talk directly to your shell

${pc.bold("Usage:")}
  npx lacy              Install, or open settings when installed
  npx lacy setup        Open settings
  npx lacy info         Show a short introduction
  npx lacy --uninstall  Remove Lacy Shell

${pc.bold("Options:")}
  -h, --help       Show this help
  -u, --uninstall  Remove Lacy Shell

${pc.bold("Other install methods:")}
  curl -fsSL https://lacy.sh/install | bash
  brew install lacymorrow/tap/lacy

${pc.dim("https://github.com/lacymorrow/lacy")}
`);
}

async function main() {
  const args = process.argv.slice(2);

  if (args.includes("--help") || args.includes("-h")) {
    printHelp();
    return;
  }

  if (args[0] === "info") {
    const result = spawnSync("bash", [join(__dirname, "commands", "info.sh")], { stdio: "inherit" });
    process.exit(result.status ?? 1);
  }

  if (args[0] === "uninstall" || args.includes("--uninstall") || args.includes("-u")) {
    await uninstall();
    return;
  }

  if (!isInteractive()) {
    if (isInstalled()) {
      console.log("No terminal detected. Updating with the bash installer, no prompts.");
      const status = runRepoScript("install.sh", ["--update"]);
      process.exit(status ?? 1);
    }
    console.log("No terminal detected. Installing with defaults, no prompts.");
    await install();
    return;
  }

  if (isInstalled()) {
    await dashboard();
    return;
  }

  await install();
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    restoreTerminalState();
    p.log.error(e.message);
    process.exit(1);
  });
