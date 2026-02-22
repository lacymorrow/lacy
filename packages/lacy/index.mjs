#!/usr/bin/env node

import * as p from "@clack/prompts";
import pc from "picocolors";
import { execSync, spawn } from "child_process";
import {
  existsSync,
  mkdirSync,
  writeFileSync,
  readFileSync,
  appendFileSync,
  rmSync,
} from "fs";
import { homedir } from "os";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const INSTALL_DIR = join(homedir(), ".lacy");
const INSTALL_DIR_OLD = join(homedir(), ".lacy-shell");
const CONFIG_FILE = join(INSTALL_DIR, "config.yaml");
const REPO_URL = "https://github.com/lacymorrow/lacy.git";

// Version — read from installed package.json (single source of truth),
// fall back to this npm package's own package.json
function getVersion() {
  // Try the installed copy first
  for (const dir of [INSTALL_DIR, INSTALL_DIR_OLD]) {
    const pkgPath = join(dir, "package.json");
    if (existsSync(pkgPath)) {
      try {
        const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
        if (pkg.version) return pkg.version;
      } catch {}
    }
  }
  // Fall back to this package's own version
  try {
    const __dirname = dirname(fileURLToPath(import.meta.url));
    const pkg = JSON.parse(readFileSync(join(__dirname, "package.json"), "utf-8"));
    if (pkg.version) return pkg.version;
  } catch {}
  return "unknown";
}

const VERSION = getVersion();

// ============================================================================
// Terminal state safety net
// ============================================================================
// @clack/prompts puts stdin into raw mode during interactive prompts. If the
// process exits abnormally (unhandled error, SIGINT during a prompt, etc.),
// raw mode is never restored and the parent shell's tty is left corrupted —
// breaking Ctrl+C, paste, and other keyboard shortcuts until a new terminal
// window is opened. These handlers ensure we always clean up.

function restoreTerminalState() {
  try {
    if (process.stdin.isTTY && process.stdin.isRaw) {
      process.stdin.setRawMode(false);
    }
  } catch {
    // stdin may already be destroyed
  }
  // Restore cursor visibility and line wrapping
  process.stdout.write("\x1b[?25h\x1b[?7h");
}

process.on("exit", restoreTerminalState);

for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => {
    restoreTerminalState();
    // Re-raise so the parent process sees the correct exit code
    process.exit(128 + ({ SIGINT: 2, SIGTERM: 15, SIGHUP: 1 }[signal]));
  });
}

// Shell detection and per-shell configuration
function detectShell() {
  const shell = process.env.SHELL || "";
  const base = shell.split("/").pop();
  if (base === "bash") return "bash";
  return "zsh"; // default
}

function getShellConfig(shell) {
  switch (shell) {
    case "bash":
      return {
        rcFile:
          process.platform === "darwin"
            ? join(homedir(), ".bash_profile")
            : join(homedir(), ".bashrc"),
        extraRcFile:
          process.platform === "darwin" ? join(homedir(), ".bashrc") : null,
        pluginFile: "lacy.plugin.bash",
        shellCmd: "bash",
        rcName: process.platform === "darwin" ? ".bash_profile" : ".bashrc",
      };
    default: // zsh
      return {
        rcFile: join(homedir(), ".zshrc"),
        extraRcFile: null,
        pluginFile: "lacy.plugin.zsh",
        shellCmd: "zsh",
        rcName: ".zshrc",
      };
  }
}

// All RC files that might contain lacy config (for uninstall)
const ALL_RC_FILES = [
  join(homedir(), ".zshrc"),
  join(homedir(), ".bashrc"),
  join(homedir(), ".bash_profile"),
  join(homedir(), ".config", "fish", "conf.d", "lacy.fish"),
];

const TOOLS = [
  { value: "lash", label: "lash", hint: "AI coding agent — lash.lacy.sh (recommended)" },
  { value: "claude", label: "claude", hint: "Claude Code CLI" },
  { value: "opencode", label: "opencode", hint: "OpenCode CLI" },
  { value: "gemini", label: "gemini", hint: "Google Gemini CLI" },
  { value: "codex", label: "codex", hint: "OpenAI Codex CLI" },
  { value: "custom", label: "Custom", hint: "enter your own command" },
  { value: "auto", label: "Auto-detect", hint: "use first available" },
  { value: "none", label: "None", hint: "I'll install one later" },
];

const MODES = [
  { value: "auto", label: "Auto", hint: "smart detection (recommended)" },
  { value: "shell", label: "Shell", hint: "all commands execute directly" },
  { value: "agent", label: "Agent", hint: "all input goes to AI" },
];

function commandExists(cmd) {
  if (!/^[a-zA-Z0-9._-]+$/.test(cmd)) return false;
  try {
    execSync(`command -v ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function isInstalled() {
  return existsSync(INSTALL_DIR) || existsSync(INSTALL_DIR_OLD);
}

function isInteractive() {
  return process.stdin.isTTY && process.stdout.isTTY;
}

// ============================================================================
// Config helpers
// ============================================================================

function readConfigValue(key) {
  if (!existsSync(CONFIG_FILE)) return "";
  const content = readFileSync(CONFIG_FILE, "utf-8");
  const match = content.match(new RegExp(`^[\\s]*${key}:\\s*(.*)$`, "m"));
  if (!match) return "";
  return match[1].replace(/["']/g, "").replace(/#.*/, "").trim();
}

function writeConfigValue(key, value) {
  if (!existsSync(CONFIG_FILE)) return;
  const content = readFileSync(CONFIG_FILE, "utf-8");
  const regex = new RegExp(`^(\\s*${key}:)\\s*.*$`, "m");
  if (regex.test(content)) {
    writeFileSync(CONFIG_FILE, content.replace(regex, `$1 ${value}`));
  }
}

// ============================================================================
// Shell restart
// ============================================================================

async function restartShell(
  message = "Restart shell now to apply changes?",
  shellCmd = null,
) {
  if (!isInteractive()) return;

  const restart = await p.confirm({
    message,
    initialValue: true,
  });

  if (p.isCancel(restart)) return;

  if (restart) {
    const cmd = shellCmd || getShellConfig(detectShell()).shellCmd;
    p.log.info(`Restarting ${cmd}...`);

    // Restore terminal state before handing off to the new shell
    restoreTerminalState();

    // Spawn a new login shell that inherits our stdio, then exit Node.
    // We use spawn (not execSync) to avoid creating a nested shell —
    // execSync("exec ...") only replaces the *child* process, not Node,
    // leaving the user in a nested shell with corrupted terminal state.
    const child = spawn(cmd, ["-l"], {
      stdio: "inherit",
      // Let the child own the terminal
      detached: false,
    });

    child.on("error", () => {
      p.log.warn(`Could not restart. Please run: exec ${cmd} -l`);
      process.exit(0);
    });

    // When the spawned shell exits (user typed 'exit'), exit Node too
    child.on("exit", (code) => {
      process.exit(code ?? 0);
    });

    // Prevent Node from exiting while the shell is running
    // (the child keeps the event loop alive via stdio, but be explicit)
    return new Promise(() => {});
  }
}

// ============================================================================
// Uninstall
// ============================================================================

// Remove lacy lines from an RC file
function removeLacyFromFile(filePath) {
  if (!existsSync(filePath)) return false;
  const content = readFileSync(filePath, "utf-8");
  if (!content.includes("lacy.plugin") && !content.includes(".lacy/bin"))
    return false;
  const cleaned = content
    .split("\n")
    .filter(
      (line) =>
        !line.includes("lacy.plugin") &&
        line.trim() !== "# Lacy Shell" &&
        !line.includes(".lacy/bin"),
    )
    .join("\n");
  writeFileSync(filePath, cleaned);
  return true;
}

// Shared uninstall logic — removes RC lines and install dirs completely
async function doUninstall({ askConfirm = true } = {}) {
  if (askConfirm) {
    const confirm = await p.confirm({
      message: "Are you sure you want to uninstall Lacy Shell?",
      initialValue: false,
    });

    if (p.isCancel(confirm) || !confirm) {
      p.cancel("Uninstall cancelled");
      process.exit(0);
    }
  }

  // Remove from all possible RC files
  const rcSpinner = p.spinner();
  rcSpinner.start("Removing from shell configs");

  let removedFrom = [];
  for (const rcFile of ALL_RC_FILES) {
    if (removeLacyFromFile(rcFile)) {
      removedFrom.push(rcFile.split("/").pop());
    }
  }

  if (removedFrom.length > 0) {
    rcSpinner.stop(`Removed from ${removedFrom.join(", ")}`);
  } else {
    rcSpinner.stop("No shell configs to clean");
  }

  // Remove installation directories
  const removeSpinner = p.spinner();
  removeSpinner.start("Removing installation");

  if (existsSync(INSTALL_DIR)) {
    rmSync(INSTALL_DIR, { recursive: true, force: true });
  }
  if (existsSync(INSTALL_DIR_OLD)) {
    rmSync(INSTALL_DIR_OLD, { recursive: true, force: true });
  }

  removeSpinner.stop("Installation removed");

  p.log.success("Lacy Shell uninstalled");

  await restartShell("Restart shell now?");

  p.outro("Restart your terminal to apply changes.");
}

async function uninstall() {
  console.clear();
  p.intro(pc.magenta(pc.bold(`  Lacy Shell  `)) + pc.dim(` v${VERSION}`));

  if (!isInstalled()) {
    p.log.warn("Lacy Shell is not installed");
    p.outro("Nothing to uninstall");
    process.exit(0);
  }

  await doUninstall();
}

// setup() is handled by the already-installed dashboard in main()

// ============================================================================
// Install
// ============================================================================

async function install() {
  console.clear();
  p.intro(pc.magenta(pc.bold(`  Lacy Shell  `)) + pc.dim(` v${VERSION}`));

  // Detect shell
  const shell = detectShell();
  const shellConfig = getShellConfig(shell);
  p.log.info(`Detected shell: ${pc.cyan(shell)}`);

  // Check prerequisites
  const prerequisites = p.spinner();
  prerequisites.start("Checking prerequisites");

  const missing = [];

  // Check for the target shell
  if (shell === "bash") {
    if (commandExists("bash")) {
      try {
        const bashVer = execSync('bash -c "echo ${BASH_VERSINFO[0]}"', {
          stdio: "pipe",
        })
          .toString()
          .trim();
        if (parseInt(bashVer) < 4) {
          missing.push(
            `bash 4+ (found bash ${bashVer}, upgrade with: brew install bash)`,
          );
        }
      } catch {
        missing.push("bash 4+");
      }
    } else {
      missing.push("bash");
    }
  } else {
    if (!commandExists("zsh")) missing.push("zsh");
  }

  if (!commandExists("git")) missing.push("git");

  if (missing.length > 0) {
    prerequisites.stop("Prerequisites check failed");
    p.log.error(`Missing required tools: ${missing.join(", ")}`);
    p.outro(pc.red("Please install missing prerequisites and try again."));
    process.exit(1);
  }

  prerequisites.stop("Prerequisites OK");

  // Detect installed tools
  let detected = [];
  for (const tool of ["lash", "claude", "opencode", "gemini", "codex"]) {
    if (commandExists(tool)) {
      detected.push(tool);
    }
  }

  if (detected.length > 0) {
    p.log.info(`Detected: ${detected.map((t) => pc.green(t)).join(", ")}`);
  } else {
    p.log.warn("No AI CLI tools detected");
    p.log.info("Lacy Shell requires an AI CLI tool to work.");

    const installLashNow = await p.confirm({
      message: `Would you like to install ${pc.green("lash")}? (AI coding agent — lash.lacy.sh)`,
      initialValue: true,
    });

    if (p.isCancel(installLashNow)) {
      p.cancel("Installation cancelled");
      process.exit(0);
    }

    if (installLashNow) {
      const lashSpinner = p.spinner();
      lashSpinner.start("Installing lash");

      try {
        if (commandExists("npm")) {
          execSync("npm install -g lashcode", { stdio: "pipe" });
          lashSpinner.stop("lash installed");
          detected.push("lash");
        } else if (commandExists("brew")) {
          execSync("brew tap lacymorrow/tap && brew install lash", {
            stdio: "pipe",
          });
          lashSpinner.stop("lash installed");
          detected.push("lash");
        } else {
          lashSpinner.stop("Could not install lash");
          p.log.warn(
            "Please install npm or homebrew, then run: npm install -g lashcode",
          );
        }
      } catch (e) {
        lashSpinner.stop("lash installation failed");
        p.log.warn(
          "You can install it manually later: npm install -g lashcode",
        );
      }
    }
  }

  // Tool selection
  const selectedTool = await p.select({
    message: "Which AI CLI tool do you want to use?",
    options: TOOLS.map((t) => ({
      value: t.value,
      label: t.label,
      hint: detected.includes(t.value) ? pc.green("installed") : t.hint,
    })),
    initialValue: detected[0] || "lash",
  });

  if (p.isCancel(selectedTool)) {
    p.cancel("Installation cancelled");
    process.exit(0);
  }

  // Prompt for custom command if selected
  let customCommand = "";
  if (selectedTool === "custom") {
    customCommand = await p.text({
      message:
        "Enter your custom command (query will be appended as a quoted argument):",
      placeholder: "claude --dangerously-skip-permissions -p",
      validate(value) {
        if (!value || value.trim().length === 0)
          return "Command cannot be empty";
      },
    });

    if (p.isCancel(customCommand)) {
      p.cancel("Installation cancelled");
      process.exit(0);
    }

    p.log.info(`Custom command: ${pc.cyan(customCommand)}`);
  }

  // Show which tool auto-detect resolves to
  if (selectedTool === "auto" && detected.length > 0) {
    p.log.info(`Using: ${pc.green("auto-detect")} (currently: ${pc.green(detected[0])})`);
  }

  // Offer to install lash if selected but not installed,
  // or if auto-detect was chosen but no tools are available
  const needsLashInstall =
    (selectedTool === "lash" && !commandExists("lash")) ||
    (selectedTool === "auto" && detected.length === 0);

  if (needsLashInstall) {
    const installLash = await p.confirm({
      message: selectedTool === "auto"
        ? `No AI CLI tools are installed. Would you like to install ${pc.green("lash")} (recommended)?`
        : "lash is not installed. Would you like to install it now?",
      initialValue: true,
    });

    if (p.isCancel(installLash)) {
      p.cancel("Installation cancelled");
      process.exit(0);
    }

    if (installLash) {
      const lashSpinner = p.spinner();
      lashSpinner.start("Installing lash");

      try {
        if (commandExists("npm")) {
          execSync("npm install -g lashcode", { stdio: "pipe" });
          lashSpinner.stop("lash installed");
        } else if (commandExists("brew")) {
          execSync("brew tap lacymorrow/tap && brew install lash", {
            stdio: "pipe",
          });
          lashSpinner.stop("lash installed");
        } else {
          lashSpinner.stop("Could not install lash");
          p.log.warn(
            "Please install npm or homebrew, then run: npm install -g lashcode",
          );
        }
      } catch (e) {
        lashSpinner.stop("lash installation failed");
        p.log.warn(
          "You can install it manually later: npm install -g lashcode",
        );
      }
    }
  }

  // Clone/update repository
  const installSpinner = p.spinner();
  installSpinner.start("Installing Lacy");

  try {
    if (existsSync(INSTALL_DIR)) {
      // Update existing
      try {
        execSync("git pull origin main", { cwd: INSTALL_DIR, stdio: "pipe" });
      } catch {
        // Ignore pull errors, use existing
      }
      installSpinner.stop("Lacy updated");
    } else {
      execSync(`git clone --depth 1 ${REPO_URL} "${INSTALL_DIR}"`, {
        stdio: "pipe",
      });
      installSpinner.stop("Lacy installed");
    }
  } catch (e) {
    installSpinner.stop("Installation failed");
    p.log.error(`Could not clone repository: ${e.message}`);
    p.outro(pc.red("Installation failed"));
    process.exit(1);
  }

  // Configure shell RC file
  const shellSpinner = p.spinner();
  shellSpinner.start(`Configuring ${shell}`);

  const { rcFile, extraRcFile, pluginFile, rcName } = shellConfig;
  const sourceLine = `source ${INSTALL_DIR}/${pluginFile}`;
  const pathLine = `export PATH="${INSTALL_DIR}/bin:$PATH"`;

  // Ensure parent directory exists
  const rcDir = rcFile.substring(0, rcFile.lastIndexOf("/"));
  mkdirSync(rcDir, { recursive: true });

  if (existsSync(rcFile)) {
    const rcContent = readFileSync(rcFile, "utf-8");

    if (rcContent.includes("lacy.plugin")) {
      shellSpinner.stop("Already configured");

      // Add PATH if missing (upgrade from older install)
      if (!rcContent.includes(".lacy/bin")) {
        appendFileSync(rcFile, `${pathLine}\n`);
      }
    } else {
      appendFileSync(rcFile, `\n# Lacy Shell\n${sourceLine}\n${pathLine}\n`);
      shellSpinner.stop(`Added to ${rcName}`);
    }
  } else {
    writeFileSync(rcFile, `# Lacy Shell\n${sourceLine}\n${pathLine}\n`);
    shellSpinner.stop(`Created ${rcName}`);
  }

  // For Bash on macOS, also add to .bashrc if it exists
  if (
    extraRcFile &&
    existsSync(extraRcFile) &&
    !readFileSync(extraRcFile, "utf-8").includes("lacy.plugin")
  ) {
    appendFileSync(extraRcFile, `\n# Lacy Shell\n${sourceLine}\n${pathLine}\n`);
  }

  // Create or update config
  const configSpinner = p.spinner();
  mkdirSync(INSTALL_DIR, { recursive: true });

  const activeToolValue =
    selectedTool === "auto" || selectedTool === "none" ? "" : selectedTool;

  if (existsSync(CONFIG_FILE)) {
    // Preserve existing config, only update tool selection
    configSpinner.start("Updating configuration");
    if (activeToolValue) {
      writeConfigValue("active", activeToolValue);
      if (selectedTool === "custom" && customCommand) {
        writeConfigValue("custom_command", `"${customCommand}"`);
      }
    }
    configSpinner.stop("Configuration preserved");
  } else {
    configSpinner.start("Creating configuration");

    const customCommandLine =
      selectedTool === "custom" && customCommand
        ? `  custom_command: "${customCommand}"`
        : `  # custom_command: "your-command -flags"`;

    const configContent = `# Lacy Shell Configuration
# https://github.com/lacymorrow/lacy

# AI CLI tool selection
# Options: lash, claude, opencode, gemini, codex, custom, or empty for auto-detect
agent_tools:
  active: ${activeToolValue}
${customCommandLine}

# API Keys (optional - only needed if no CLI tool is installed)
api_keys:
  # openai: "your-key-here"
  # anthropic: "your-key-here"

# Operating modes
modes:
  default: auto  # Options: shell, agent, auto

# Smart auto-detection settings
auto_detection:
  enabled: true
  confidence_threshold: 0.7
`;

    writeFileSync(CONFIG_FILE, configContent);
    configSpinner.stop("Configuration created");
  }

  // Re-read version after install (repo was just cloned/updated)
  const installedVersion = getVersion();

  // Success message
  p.log.success(pc.green(`Installation complete!`) + pc.dim(` v${installedVersion}`));

  p.note(
    `${pc.cyan("what files are here")}  ${pc.dim("→ AI answers")}
${pc.cyan("ls -la")}               ${pc.dim("→ runs in shell")}

Commands:
  ${pc.cyan("mode")}        ${pc.dim("Show/change mode")}
  ${pc.cyan("tool")}        ${pc.dim("Show/change AI tool")}
  ${pc.cyan('ask "q"')}     ${pc.dim("Direct query to AI")}
  ${pc.cyan("lacy setup")}  ${pc.dim("Interactive settings")}`,
    "Try it",
  );

  if (
    selectedTool === "none" ||
    (selectedTool === "auto" && detected.length === 0)
  ) {
    p.log.warn("Remember to install an AI CLI tool:");
    console.log(`  ${pc.cyan("npm install -g lashcode")}`);
  }

  await restartShell();

  p.outro(pc.dim("Learn more: https://github.com/lacymorrow/lacy"));
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  const args = process.argv.slice(2);

  // Handle info subcommand
  if (args[0] === "info") {
    const infoPath = join(INSTALL_DIR, "lib/commands/info.sh");
    if (existsSync(infoPath)) {
      const content = readFileSync(infoPath, "utf-8");
      console.log(content);
    } else {
      console.log(`\n${pc.magenta(pc.bold("🔧 Lacy Shell"))} v${VERSION}\n`);
      console.log("Lacy Shell detects natural language and routes it to AI coding agents.\n");
      console.log("Quick tips:");
      console.log("  • Type normally for shell commands");
      console.log("  • Type natural language for AI assistance");
      console.log("  • Press Ctrl+Space to toggle modes\n");
      console.log(`Run '${pc.cyan("lacy setup")}' to configure your AI tool and settings.`);
      console.log(`Run '${pc.cyan("lacy mode")}' to see current mode and legend.`);
    }
    return;
  }

  // Handle uninstall subcommand/flag
  if (args[0] === "uninstall") {
    await uninstall();
    return;
  }

  if (args.includes("--uninstall") || args.includes("-u")) {
    await uninstall();
    return;
  }

  if (args.includes("--help") || args.includes("-h")) {
    console.log(`
${pc.magenta(pc.bold("Lacy Shell"))} ${pc.dim(`v${VERSION}`)} - Talk directly to your shell

${pc.bold("Usage:")}
  npx lacy              Install Lacy Shell
  npx lacy --uninstall  Uninstall Lacy Shell
  npx lacy setup        Interactive settings

${pc.bold("Options:")}
  -h, --help       Show this help message
  -u, --uninstall  Uninstall Lacy Shell

${pc.bold("Commands:")}
  setup            Interactive settings (tool, mode, config)
  info             Show basic information and help

${pc.bold("Other install methods:")}
  curl -fsSL https://lacy.sh/install | bash
  brew install lacymorrow/tap/lacy

${pc.dim("https://github.com/lacymorrow/lacy")}
`);
    return;
  }

  // If already installed, show dashboard + menu
  if (isInstalled()) {
    console.clear();
    p.intro(pc.magenta(pc.bold(`  Lacy Shell  `)) + pc.dim(` v${VERSION}`));

    // Show current status
    const active = readConfigValue("active");
    const mode = readConfigValue("default");
    const detected = [];
    for (const tool of ["lash", "claude", "opencode", "gemini", "codex"]) {
      if (commandExists(tool)) detected.push(tool);
    }

    const toolDisplay = active || "auto-detect";
    const modeDisplay = mode || "auto";
    const toolsDisplay =
      detected.length > 0
        ? detected.map((t) => pc.green(t)).join(", ")
        : pc.yellow("none");

    p.note(
      `  Tool:       ${pc.cyan(toolDisplay)}
  Mode:       ${pc.cyan(modeDisplay)}
  Installed:  ${toolsDisplay}`,
      "Current config",
    );

    let loop = true;
    while (loop) {
      const action = await p.select({
        message: "What would you like to do?",
        options: [
          {
            value: "tool",
            label: "Change AI tool",
            hint: `current: ${active || "auto-detect"}`,
          },
          {
            value: "mode",
            label: "Change mode",
            hint: `current: ${modeDisplay}`,
          },
          { value: "config", label: "Edit config", hint: "open in $EDITOR" },
          {
            value: "status",
            label: "Status",
            hint: "show full installation info",
          },
          { value: "update", label: "Update", hint: "pull latest changes" },
          {
            value: "reinstall",
            label: "Reinstall",
            hint: "fresh installation",
          },
          {
            value: "uninstall",
            label: "Uninstall",
            hint: "remove Lacy Shell",
          },
          { value: "done", label: "Done" },
        ],
      });

      if (p.isCancel(action) || action === "done") {
        loop = false;
        break;
      }

      if (action === "tool") {
        const selectedTool = await p.select({
          message: "Which AI CLI tool do you want to use?",
          options: TOOLS.filter((t) => t.value !== "none").map((t) => ({
            value: t.value,
            label: t.label,
            hint: detected.includes(t.value) ? pc.green("installed") : t.hint,
          })),
          initialValue: active || detected[0] || "auto",
        });

        if (p.isCancel(selectedTool)) continue;

        if (selectedTool === "custom") {
          const customCmd = await p.text({
            message:
              "Enter your custom command (query will be appended as a quoted argument):",
            placeholder: "claude --dangerously-skip-permissions -p",
            validate(value) {
              if (!value || value.trim().length === 0)
                return "Command cannot be empty";
            },
          });
          if (p.isCancel(customCmd)) continue;
          writeConfigValue("active", "custom");
          writeConfigValue("custom_command", `"${customCmd}"`);
          p.log.success(`Tool set to: ${pc.cyan("custom")} (${customCmd})`);
        } else if (selectedTool === "auto") {
          writeConfigValue("active", "");
          p.log.success(`Tool set to: ${pc.cyan("auto-detect")}`);
        } else {
          writeConfigValue("active", selectedTool);
          p.log.success(`Tool set to: ${pc.cyan(selectedTool)}`);
        }

        await restartShell("Restart shell now to apply changes?");
        loop = false;
      }

      if (action === "mode") {
        const selectedMode = await p.select({
          message: "Which default mode?",
          options: MODES.map((m) => ({
            value: m.value,
            label: m.label,
            hint: m.hint,
          })),
          initialValue: mode || "auto",
        });

        if (p.isCancel(selectedMode)) continue;

        writeConfigValue(
          "default",
          `${selectedMode}  # Options: shell, agent, auto`,
        );
        p.log.success(`Mode set to: ${pc.cyan(selectedMode)}`);

        await restartShell("Restart shell now to apply changes?");
        loop = false;
      }

      if (action === "config") {
        const editor = process.env.EDITOR || process.env.VISUAL || "vi";
        p.log.info(`Opening ${pc.cyan(CONFIG_FILE)} in ${editor}...`);
        try {
          execSync(`${editor} "${CONFIG_FILE}"`, { stdio: "inherit" });
        } catch {
          p.log.warn("Editor closed");
        }

        await restartShell("Restart shell now to apply changes?");
        loop = false;
      }

      if (action === "status") {
        const dir = existsSync(INSTALL_DIR) ? INSTALL_DIR : INSTALL_DIR_OLD;
        let sha = "";
        try {
          sha = execSync("git rev-parse --short HEAD", {
            cwd: dir,
            stdio: "pipe",
          })
            .toString()
            .trim();
        } catch {}

        const shell = detectShell();
        const rc = getShellConfig(shell).rcFile;
        const rcConfigured =
          existsSync(rc) && readFileSync(rc, "utf-8").includes("lacy.plugin");
        const hasConfig = existsSync(CONFIG_FILE);

        const lines = [
          `  Installed:  ${pc.green(dir)}`,
          `  Version:    ${pc.cyan("v" + VERSION)}${sha ? pc.dim(` (${sha})`) : ""}`,
          `  Shell:      ${pc.cyan(shell)} ${rcConfigured ? pc.green("configured") : pc.yellow("not configured")}`,
          `  Config:     ${hasConfig ? pc.green("exists") : pc.yellow("missing")}`,
          `  Tool:       ${pc.cyan(active || "auto-detect")}`,
          `  Mode:       ${pc.cyan(modeDisplay)}`,
          ``,
          `  ${pc.bold("AI CLI tools:")}`,
          ...["lash", "claude", "opencode", "gemini", "codex"].map((t) =>
            commandExists(t)
              ? `    ${pc.green("✓")} ${t}`
              : `    ${pc.dim("○")} ${pc.dim(t)}`,
          ),
        ].filter(Boolean);

        p.note(lines.join("\n"), "Status");
        // Don't break, let user pick another action
      }

      if (action === "uninstall") {
        await doUninstall();
        return;
      }

      if (action === "update") {
        const updateSpinner = p.spinner();
        updateSpinner.start("Updating Lacy");
        const updateDir = existsSync(INSTALL_DIR)
          ? INSTALL_DIR
          : INSTALL_DIR_OLD;
        try {
          execSync("git pull origin main", { cwd: updateDir, stdio: "pipe" });
          const updatedVersion = getVersion();
          updateSpinner.stop(`Lacy updated to v${updatedVersion}`);
          p.log.success("Update complete!");
          await restartShell();
          p.outro("Restart your terminal to apply changes.");
        } catch {
          updateSpinner.stop("Update failed");
          p.log.error("Could not update. Try reinstalling instead.");
        }
        return;
      }

      if (action === "reinstall") {
        const removeSpinner = p.spinner();
        removeSpinner.start("Removing existing installation");
        // Backup config before removing
        let configBackup = null;
        if (existsSync(CONFIG_FILE)) {
          configBackup = readFileSync(CONFIG_FILE, "utf-8");
        }
        if (existsSync(INSTALL_DIR)) {
          rmSync(INSTALL_DIR, { recursive: true, force: true });
        }
        if (existsSync(INSTALL_DIR_OLD)) {
          rmSync(INSTALL_DIR_OLD, { recursive: true, force: true });
        }
        // Restore config so install() sees it and preserves it
        if (configBackup) {
          mkdirSync(INSTALL_DIR, { recursive: true });
          writeFileSync(CONFIG_FILE, configBackup);
        }
        removeSpinner.stop("Removed");
        loop = false;
        // Falls through to install()
      }
    }

    // Only reach here if reinstall was selected (or loop ended without return)
    if (!isInstalled()) {
      await install();
    } else {
      p.outro(pc.dim("https://github.com/lacymorrow/lacy"));
    }
    return;
  }

  await install();
}

main().catch((e) => {
  restoreTerminalState();
  p.log.error(e.message);
  process.exit(1);
});
