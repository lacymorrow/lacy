#!/usr/bin/env node

import * as p from '@clack/prompts';
import pc from 'picocolors';
import { execSync, spawn } from 'child_process';
import { existsSync, mkdirSync, writeFileSync, readFileSync, appendFileSync, rmSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

const INSTALL_DIR = join(homedir(), '.lacy');
const INSTALL_DIR_OLD = join(homedir(), '.lacy-shell');
const CONFIG_FILE = join(INSTALL_DIR, 'config.yaml');
const ZSHRC = join(homedir(), '.zshrc');
const REPO_URL = 'https://github.com/lacymorrow/lacy.git';

const TOOLS = [
  { value: 'lash', label: 'lash', hint: 'recommended' },
  { value: 'claude', label: 'claude', hint: 'Claude Code CLI' },
  { value: 'opencode', label: 'opencode', hint: 'OpenCode CLI' },
  { value: 'gemini', label: 'gemini', hint: 'Google Gemini CLI' },
  { value: 'codex', label: 'codex', hint: 'OpenAI Codex CLI' },
  { value: 'custom', label: 'Custom', hint: 'enter your own command' },
  { value: 'auto', label: 'Auto-detect', hint: 'use first available' },
  { value: 'none', label: 'None', hint: "I'll install one later" },
];

function commandExists(cmd) {
  try {
    execSync(`command -v ${cmd}`, { stdio: 'ignore' });
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

async function restartShell(message = 'Restart shell now to apply changes?') {
  if (!isInteractive()) return;

  const restart = await p.confirm({
    message,
    initialValue: true,
  });

  if (p.isCancel(restart)) return;

  if (restart) {
    p.log.info('Restarting shell...');
    // Use spawn with shell to exec into zsh
    const child = spawn('zsh', ['-l'], {
      stdio: 'inherit',
      shell: false,
    });
    child.on('exit', () => process.exit(0));
    // Keep the process alive until zsh exits
    await new Promise(() => {});
  }
}

// ============================================================================
// Uninstall
// ============================================================================

async function uninstall() {
  console.clear();
  p.intro(pc.magenta(pc.bold(`  Lacy Shell  `)));

  if (!isInstalled()) {
    p.log.warn('Lacy Shell is not installed');
    p.outro('Nothing to uninstall');
    process.exit(0);
  }

  const confirm = await p.confirm({
    message: 'Are you sure you want to uninstall Lacy Shell?',
    initialValue: false,
  });

  if (p.isCancel(confirm) || !confirm) {
    p.cancel('Uninstall cancelled');
    process.exit(0);
  }

  // Remove from .zshrc
  const zshrcSpinner = p.spinner();
  zshrcSpinner.start('Removing from .zshrc');

  if (existsSync(ZSHRC)) {
    let content = readFileSync(ZSHRC, 'utf-8');
    // Remove source line and comment
    content = content
      .split('\n')
      .filter(line => !line.includes('lacy.plugin.zsh') && line.trim() !== '# Lacy Shell')
      .join('\n');
    writeFileSync(ZSHRC, content);
    zshrcSpinner.stop('Removed from .zshrc');
  } else {
    zshrcSpinner.stop('No .zshrc found');
  }

  // Remove installation directories
  const removeSpinner = p.spinner();
  removeSpinner.start('Removing installation');

  if (existsSync(INSTALL_DIR)) {
    rmSync(INSTALL_DIR, { recursive: true, force: true });
  }
  if (existsSync(INSTALL_DIR_OLD)) {
    rmSync(INSTALL_DIR_OLD, { recursive: true, force: true });
  }

  removeSpinner.stop('Installation removed');

  p.log.success('Lacy Shell uninstalled');

  await restartShell('Restart shell now?');

  p.outro(`Run ${pc.cyan('source ~/.zshrc')} or restart your terminal.`);
}

// ============================================================================
// Install
// ============================================================================

async function install() {
  console.clear();
  p.intro(pc.magenta(pc.bold(`  Lacy Shell  `)));

  // Check prerequisites
  const prerequisites = p.spinner();
  prerequisites.start('Checking prerequisites');

  const missing = [];
  if (!commandExists('zsh')) missing.push('zsh');
  if (!commandExists('git')) missing.push('git');

  if (missing.length > 0) {
    prerequisites.stop('Prerequisites check failed');
    p.log.error(`Missing required tools: ${missing.join(', ')}`);
    p.outro(pc.red('Please install missing prerequisites and try again.'));
    process.exit(1);
  }

  prerequisites.stop('Prerequisites OK');

  // Detect installed tools
  const detected = [];
  for (const tool of ['lash', 'claude', 'opencode', 'gemini', 'codex']) {
    if (commandExists(tool)) {
      detected.push(tool);
    }
  }

  if (detected.length > 0) {
    p.log.info(`Detected: ${detected.map(t => pc.green(t)).join(', ')}`);
  } else {
    p.log.warn('No AI CLI tools detected');
  }

  // Tool selection
  const selectedTool = await p.select({
    message: 'Which AI CLI tool do you want to use?',
    options: TOOLS.map(t => ({
      value: t.value,
      label: t.label,
      hint: detected.includes(t.value)
        ? pc.green('installed')
        : t.hint,
    })),
    initialValue: detected[0] || 'lash',
  });

  if (p.isCancel(selectedTool)) {
    p.cancel('Installation cancelled');
    process.exit(0);
  }

  // Prompt for custom command if selected
  let customCommand = '';
  if (selectedTool === 'custom') {
    customCommand = await p.text({
      message: 'Enter your custom command (query will be appended as a quoted argument):',
      placeholder: 'claude --dangerously-skip-permissions -p',
      validate(value) {
        if (!value || value.trim().length === 0) return 'Command cannot be empty';
      },
    });

    if (p.isCancel(customCommand)) {
      p.cancel('Installation cancelled');
      process.exit(0);
    }

    p.log.info(`Custom command: ${pc.cyan(customCommand)}`);
  }

  // Offer to install lash if selected but not installed
  if (selectedTool === 'lash' && !commandExists('lash')) {
    const installLash = await p.confirm({
      message: 'lash is not installed. Would you like to install it now?',
      initialValue: true,
    });

    if (p.isCancel(installLash)) {
      p.cancel('Installation cancelled');
      process.exit(0);
    }

    if (installLash) {
      const lashSpinner = p.spinner();
      lashSpinner.start('Installing lash');

      try {
        if (commandExists('npm')) {
          execSync('npm install -g lash-cli', { stdio: 'pipe' });
          lashSpinner.stop('lash installed');
        } else if (commandExists('brew')) {
          execSync('brew tap lacymorrow/tap && brew install lash', { stdio: 'pipe' });
          lashSpinner.stop('lash installed');
        } else {
          lashSpinner.stop('Could not install lash');
          p.log.warn('Please install npm or homebrew, then run: npm install -g lash-cli');
        }
      } catch (e) {
        lashSpinner.stop('lash installation failed');
        p.log.warn('You can install it manually later: npm install -g lash-cli');
      }
    }
  }

  // Clone/update repository
  const installSpinner = p.spinner();
  installSpinner.start('Installing Lacy');

  try {
    if (existsSync(INSTALL_DIR)) {
      // Update existing
      try {
        execSync('git pull origin main', { cwd: INSTALL_DIR, stdio: 'pipe' });
      } catch {
        // Ignore pull errors, use existing
      }
      installSpinner.stop('Lacy updated');
    } else {
      execSync(`git clone --depth 1 ${REPO_URL} "${INSTALL_DIR}"`, { stdio: 'pipe' });
      installSpinner.stop('Lacy installed');
    }
  } catch (e) {
    installSpinner.stop('Installation failed');
    p.log.error(`Could not clone repository: ${e.message}`);
    p.outro(pc.red('Installation failed'));
    process.exit(1);
  }

  // Configure .zshrc
  const zshrcSpinner = p.spinner();
  zshrcSpinner.start('Configuring shell');

  const sourceLine = `source ${INSTALL_DIR}/lacy.plugin.zsh`;

  if (existsSync(ZSHRC)) {
    const zshrcContent = readFileSync(ZSHRC, 'utf-8');

    if (zshrcContent.includes('lacy.plugin.zsh')) {
      zshrcSpinner.stop('Already configured');
    } else {
      appendFileSync(ZSHRC, `\n# Lacy Shell\n${sourceLine}\n`);
      zshrcSpinner.stop('Added to .zshrc');
    }
  } else {
    writeFileSync(ZSHRC, `# Lacy Shell\n${sourceLine}\n`);
    zshrcSpinner.stop('Created .zshrc');
  }

  // Create config
  const configSpinner = p.spinner();
  configSpinner.start('Creating configuration');

  mkdirSync(INSTALL_DIR, { recursive: true });

  const activeToolValue = selectedTool === 'auto' || selectedTool === 'none' ? '' : selectedTool;

  const customCommandLine = selectedTool === 'custom' && customCommand
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
  configSpinner.stop('Configuration created');

  // Success message
  p.log.success(pc.green('Installation complete!'));

  p.note(
    `${pc.cyan('what files are here')}  ${pc.dim('→ AI answers')}
${pc.cyan('ls -la')}               ${pc.dim('→ runs in shell')}

Commands:
  ${pc.cyan('mode')}     ${pc.dim('Show/change mode')}
  ${pc.cyan('tool')}     ${pc.dim('Show/change AI tool')}
  ${pc.cyan('ask "q"')}  ${pc.dim('Direct query to AI')}`,
    'Try it'
  );

  if (selectedTool === 'none' || (selectedTool === 'auto' && detected.length === 0)) {
    p.log.warn('Remember to install an AI CLI tool:');
    console.log(`  ${pc.cyan('npm install -g lash-cli')}`);
  }

  await restartShell();

  p.outro(pc.dim('Learn more: https://github.com/lacymorrow/lacy'));
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  const args = process.argv.slice(2);

  // Handle flags
  if (args.includes('--uninstall') || args.includes('-u')) {
    await uninstall();
    return;
  }

  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
${pc.magenta(pc.bold('Lacy Shell'))} - Talk directly to your shell

${pc.bold('Usage:')}
  npx lacy              Install Lacy Shell
  npx lacy --uninstall  Uninstall Lacy Shell

${pc.bold('Options:')}
  -h, --help       Show this help message
  -u, --uninstall  Uninstall Lacy Shell

${pc.bold('Other install methods:')}
  curl -fsSL https://lacy.sh/install | bash
  brew install lacymorrow/tap/lacy

${pc.dim('https://github.com/lacymorrow/lacy')}
`);
    return;
  }

  // If already installed, offer choices
  if (isInstalled()) {
    console.clear();
    p.intro(pc.magenta(pc.bold(`  Lacy Shell  `)));

    const action = await p.select({
      message: 'Lacy Shell is already installed. What would you like to do?',
      options: [
        { value: 'update', label: 'Update', hint: 'pull latest changes' },
        { value: 'reinstall', label: 'Reinstall', hint: 'fresh installation' },
        { value: 'uninstall', label: 'Uninstall', hint: 'remove Lacy Shell' },
        { value: 'cancel', label: 'Cancel', hint: 'do nothing' },
      ],
    });

    if (p.isCancel(action) || action === 'cancel') {
      p.cancel('Cancelled');
      process.exit(0);
    }

    if (action === 'uninstall') {
      // Skip the intro since we already showed it
      const confirm = await p.confirm({
        message: 'Are you sure you want to uninstall Lacy Shell?',
        initialValue: false,
      });

      if (p.isCancel(confirm) || !confirm) {
        p.cancel('Uninstall cancelled');
        process.exit(0);
      }

      // Remove from .zshrc
      const zshrcSpinner = p.spinner();
      zshrcSpinner.start('Removing from .zshrc');

      if (existsSync(ZSHRC)) {
        let content = readFileSync(ZSHRC, 'utf-8');
        content = content
          .split('\n')
          .filter(line => !line.includes('lacy.plugin.zsh') && line.trim() !== '# Lacy Shell')
          .join('\n');
        writeFileSync(ZSHRC, content);
        zshrcSpinner.stop('Removed from .zshrc');
      } else {
        zshrcSpinner.stop('No .zshrc found');
      }

      // Remove installation
      const removeSpinner = p.spinner();
      removeSpinner.start('Removing installation');

      if (existsSync(INSTALL_DIR)) {
        rmSync(INSTALL_DIR, { recursive: true, force: true });
      }
      if (existsSync(INSTALL_DIR_OLD)) {
        rmSync(INSTALL_DIR_OLD, { recursive: true, force: true });
      }

      removeSpinner.stop('Installation removed');

      p.log.success('Lacy Shell uninstalled');

      await restartShell('Restart shell now?');

      p.outro(`Run ${pc.cyan('source ~/.zshrc')} or restart your terminal.`);
      return;
    }

    if (action === 'update') {
      const updateSpinner = p.spinner();
      updateSpinner.start('Updating Lacy');

      try {
        execSync('git pull origin main', { cwd: INSTALL_DIR, stdio: 'pipe' });
        updateSpinner.stop('Lacy updated');
        p.log.success('Update complete!');

        await restartShell();

        p.outro(`Run ${pc.cyan('source ~/.zshrc')} or restart your terminal.`);
      } catch {
        updateSpinner.stop('Update failed');
        p.log.error('Could not update. Try reinstalling instead.');
        p.outro('');
      }
      return;
    }

    if (action === 'reinstall') {
      // Remove existing and continue to install
      const removeSpinner = p.spinner();
      removeSpinner.start('Removing existing installation');

      if (existsSync(INSTALL_DIR)) {
        rmSync(INSTALL_DIR, { recursive: true, force: true });
      }
      if (existsSync(INSTALL_DIR_OLD)) {
        rmSync(INSTALL_DIR_OLD, { recursive: true, force: true });
      }

      removeSpinner.stop('Removed');
    }
  }

  await install();
}

main().catch((e) => {
  p.log.error(e.message);
  process.exit(1);
});
