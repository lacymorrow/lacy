# Changelog

All notable changes to Lacy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-02-03

### Added
- Agent preheating to reduce per-query latency
- Background server mode for lash and opencode — starts `lash serve` / `opencode serve` in background, routes queries via local REST API to eliminate cold-start
- Claude session reuse — captures `session_id` from `--output-format json` and passes `--resume` on subsequent queries for conversation continuity
- New `preheat` config section with `eager` (start server on plugin load) and `server_port` (default 4096) options
- Automatic server lifecycle management: lazy start on first query, health checks, crash recovery, cleanup on quit or tool switch

### Fixed
- Fixed JSON output parsing in zsh — replaced `echo` with `printf '%s\n'` to prevent zsh from interpreting escape sequences (`\n`, `\"`) in JSON strings

---

## [1.1.1] - 2026-02-03

### Fixed
- Leading whitespace no longer misroutes input to agent (`  ls -la` now correctly executes in shell)
- Spinner no longer permanently disables job control (`fg`/`bg` work after AI queries)
- Spinner no longer leaves cursor hidden after Ctrl+C interrupts
- `exit` no longer shadowed by alias — passes through to shell builtin in shell mode, quits lacy in auto/agent mode

### Changed
- Centralized detection logic into single `lacy_shell_classify_input()` function — indicator and execution can no longer disagree
- Added single-entry cache for `command -v` lookups to reduce input lag with large PATH

---

## [1.1.0] - 2024-12-19 - SMART AUTO MODE 🧠

### ⚡ Major Enhancement: Intelligent Auto Mode

**Smart Command Execution**: Auto mode now executes real commands first, then falls back to AI
- **Command-First Strategy**: Real shell commands execute immediately without AI overhead
- **Natural Language Detection**: Obvious questions go directly to AI (no failed shell attempts)
- **Smart Fallback**: Unknown commands try shell first, then automatically ask AI for help
- **Better Performance**: Eliminates unnecessary AI calls for standard commands

### 🎯 New Smart Auto Mode Features
- `lacy_shell_execute_smart_auto()` - Core smart execution logic
- `lacy_shell_command_exists()` - Robust command existence checking (includes builtins)
- `lacy_shell_is_obvious_natural_language()` - Natural language pattern detection
- Smart routing indicators: 💻 for commands, 🤖 for AI, ❓ for fallback attempts

### 🧪 Testing & Validation
- `test-smart-auto.sh` - Comprehensive test suite for smart auto mode
- `test_smart_auto` alias for quick function testing
- Real-world test cases covering edge cases and common scenarios

### 📈 Performance Improvements
- ⚡ Real commands execute instantly (no AI delay)
- 🧠 Natural language bypasses shell attempts
- 🔄 Graceful fallback maintains workflow continuity
- 📚 Educational feedback when introducing new tools

### 🔄 Breaking Changes
- Auto mode behavior significantly improved (backwards compatible)
- Detection logic now optimized for performance over pattern matching
- Mode descriptions updated to reflect new "try shell first" behavior

---

## [1.0.1] - 2024-12-19 - PRODUCTION HARDENING 🛡️

### 🚨 Critical Fixes
- **Fixed Input "Swallowing" Issue**: Resolved commands disappearing with no feedback
- **MCP Server Error Handling**: Added proper startup validation and error reporting
- **Emergency Recovery System**: Multiple escape routes when things go wrong
- **API Timeout Protection**: 30-second timeout prevents hanging on AI calls

### 🔧 New Emergency Commands
- `!command` - Emergency bypass prefix for direct shell execution
- `disable_lacy` - Disable input interception entirely (alias: `lacy_shell_disable_interception`)
- `enable_lacy` - Re-enable input interception (alias: `lacy_shell_enable_interception`)
- `mcp_check` - Verify MCP package dependencies with installation instructions
- `mode status` - Show detailed mode information including persistence state

### 🛡️ Reliability Improvements
- Pre-flight API key validation before agent execution
- Process validation for MCP servers with PID checking
- Clear error messages with actionable troubleshooting steps
- Graceful fallback to shell execution when AI services unavailable
- Enhanced error logging for MCP server diagnostics

### 📚 Documentation Updates
- Comprehensive troubleshooting section in README
- Emergency recovery procedures in all docs
- API documentation for new diagnostic functions
- Architecture docs updated with error handling patterns

### 🎯 Mode Persistence Enhancement
- **Persistent Mode Memory**: Your preferred mode is saved across shell sessions
- Mode state file: `~/.lacy-shell/current_mode`
- Enhanced `mode status` command shows current, default, and saved modes
- Graceful handling of invalid saved modes with fallback to default

## [1.0.0] - 2024-12-19

### 🎉 Initial Release

#### Added
- **Three intelligent modes**: Shell, Agent, and Auto
- **Smart mode switching** with `Ctrl+Space` keybinding
- **AI integration** with OpenAI and Anthropic APIs
- **Streaming responses** with typewriter effect
- **Persistent conversation history** across sessions
- **MCP (Model Context Protocol) support** for extensible AI capabilities
- **Auto-detection engine** for command vs. query classification
- **Visual mode indicators** in shell prompt
- **Comprehensive configuration system** via YAML
- **Zero-configuration setup** with sensible defaults

#### Features

**Core Functionality:**
- 🐚 **Shell Mode** (`$`) - Pure shell execution
- 🤖 **Agent Mode** (`?`) - AI-powered assistance
- ⚡ **Auto Mode** (`~`) - Smart routing between shell and agent

**User Interface:**
- Single-character mode indicators on prompt right side
- Clean, minimal visual design
- Real-time streaming AI responses
- Context-aware help system

**AI Integration:**
- Support for OpenAI GPT-4 and Anthropic Claude models
- Conversation memory and context preservation
- Streaming responses for real-time feedback
- MCP server integration framework

**Smart Detection:**
- Keyword-based classification (help, how, what, etc.)
- Command pattern recognition (git, npm, docker, etc.)
- Natural language query detection
- Customizable detection rules

**Configuration:**
- YAML-based configuration with fallback parsing
- API key management
- MCP server configuration
- Custom detection keywords and commands

**Keybindings:**
- `Ctrl+Space` - Primary mode toggle (universal compatibility)
- `Ctrl+T` - Alternative mode toggle
- `Ctrl+X` prefix commands for direct mode switching
- Compatible with Mac, VS Code, and all major terminals

**Developer Features:**
- Modular architecture with clear separation of concerns
- Comprehensive test suite
- Debug and troubleshooting commands
- Extension points for custom functionality

#### Technical Implementation

**Architecture:**
- ZSH plugin with widget-based input interception
- Modular design with 7 core components
- Hook-based integration with existing shell setups
- Thread-safe mode management

**Performance:**
- Lazy loading for fast startup
- Minimal memory footprint
- Efficient detection algorithms
- API response caching

**Compatibility:**
- Works with zsh, starship, oh-my-zsh
- MacOS, Linux, and WSL support
- VS Code terminal integration
- Compatible with existing shell configurations

**Security:**
- Local API key storage
- No automatic command execution from AI
- Sandboxed execution environment
- User-controlled data sharing

#### Installation & Setup

**Installation Methods:**
- Automated installer script
- Manual plugin installation
- Package manager support (planned)

**Dependencies:**
- zsh shell
- Python 3.x for configuration parsing
- curl for API communication
- Optional: Node.js for MCP servers

#### Documentation

**Comprehensive Documentation:**
- User guide with examples
- API documentation for developers
- Architecture deep dive
- Contributing guidelines
- Troubleshooting guide

**Example Workflows:**
- Development assistance scenarios
- System administration tasks
- Learning and exploration use cases
- Debugging and problem-solving

### Known Issues

- JSON escaping edge cases in complex queries (workaround available)
- MCP server integration is framework-only (servers not auto-started)
- Limited to zsh shell (other shells planned for future releases)

### Breaking Changes

None (initial release)

### Migration Guide

None (initial release)

---

## [Unreleased]

### Planned Features

#### v1.1.0 (Next Minor Release)
- **Fish shell support**
- **Bash compatibility layer** 
- **Real MCP server auto-startup**
- **Performance optimizations**
- **Extended configuration options**

#### v1.2.0 (Future Release)
- **Machine learning-based detection**
- **Plugin ecosystem support**
- **Team collaboration features**
- **Enhanced MCP integrations**
- **Custom themes and styling**

#### v2.0.0 (Major Release)
- **Multi-shell architecture**
- **Advanced AI model support**
- **Workflow automation**
- **Enterprise features**
- **Cloud synchronization**

### Development Roadmap

**Short Term (1-3 months):**
- Bug fixes and stability improvements
- Community feedback integration
- Documentation enhancements
- Performance optimizations

**Medium Term (3-6 months):**
- Shell compatibility expansion
- MCP ecosystem development
- Advanced AI features
- Plugin architecture

**Long Term (6+ months):**
- Enterprise features
- Cloud integration
- Machine learning enhancements
- Advanced automation capabilities

---

## Version History Summary

| Version | Release Date | Key Features |
|---------|--------------|--------------|
| 1.0.1   | 2024-12-19   | Production hardening: error handling, emergency recovery, mode persistence |
| 1.0.0   | 2024-12-19   | Initial release with three modes, AI integration, MCP support |

## Contributors

- **Initial Development**: Lacy Shell Team
- **Architecture Design**: Core development team
- **Documentation**: Community contributors
- **Testing**: Beta user community

## Acknowledgments

- Inspired by Warp Terminal's AI integration
- Built on the Model Context Protocol (MCP) standard
- Thanks to the zsh and shell scripting community
- OpenAI and Anthropic for AI API access

---

*For detailed technical changes, see the git commit history.*
*For upgrade instructions, see the [README.md](README.md) file.*
