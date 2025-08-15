# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lacy Shell is a production-ready zsh plugin that integrates AI capabilities directly into the terminal. It operates through three intelligent modes: Shell Mode (`$`), Agent Mode (`?`), and Auto Mode (`~`), using the Model Context Protocol (MCP) for tool integration.

## Essential Commands

### Installation & Setup
```bash
./install.sh                  # Full installation
./install.sh --local         # Local development setup
cd agent && bun install && bun run build  # Build TypeScript agent
```

### Testing
```bash
npm test                     # Run main test suite
./test.sh                    # Core functionality tests
./test-smart-auto.sh         # Smart auto mode tests
./test-mcp.sh               # MCP integration tests
./test-mode-persistence.sh   # Mode persistence tests
```

### Development
```bash
source lacy-shell.plugin.zsh  # Reload plugin for testing
lacy_shell_test_detection    # Test detection logic
lacy_shell_test_mcp         # Test MCP configuration
```

## Architecture Overview

### Core Module Structure
The plugin follows a modular architecture with clear separation of concerns:

- **lacy-shell.plugin.zsh**: Main entry point that orchestrates all modules and manages zsh integration
- **lib/modes.zsh**: Handles mode switching between Shell (`$`), Agent (`?`), and Auto (`~`) modes
- **lib/detection.zsh**: Smart detection engine that analyzes input to determine if it's a shell command or AI query
- **lib/execute.zsh**: Intercepts zsh's accept-line widget to route commands appropriately
- **lib/mcp.zsh**: Manages MCP server lifecycle and AI API integration
- **lib/config.zsh**: YAML configuration parsing and environment variable management
- **agent/**: TypeScript-based coding agent with file operations, search, and git integration
  - Compiled to native binary using Bun for fast execution
  - Supports OpenAI and Anthropic APIs
  - Includes tools for reading, writing, editing files, searching code, and running commands

### Key Integration Points

1. **Input Interception**: The plugin overrides zsh's `accept-line` widget to analyze and route commands before execution. This happens in `lib/execute.zsh` through the `lacy_shell_accept_line` function.

2. **Mode Persistence**: Mode state is maintained across sessions using `$HOME/.lacy_shell_mode` file, managed by `lib/modes.zsh`.

3. **MCP Server Management**: The plugin spawns and manages MCP server processes (filesystem and web servers) as background processes, tracked in `/tmp/lacy_mcp_*.pid` files.

4. **Configuration Flow**: 
   - Primary: `~/.lacy-shell/config.yaml`
   - Fallback: Environment variables (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`)
   - Parsed by Python helper or zsh fallback parser

### Smart Auto Mode Detection Algorithm

The detection system in `lib/detection.zsh` uses multiple heuristics:
- Command prefix matching (ls, git, npm, cd, etc.)
- Question indicators (?, how, what, why, explain)
- Natural language patterns
- Complexity analysis (word count, special characters)

### Testing Strategy

All test files follow a consistent pattern:
1. Source the plugin
2. Test specific functionality
3. Clean up any state changes
4. Return appropriate exit codes

Tests are designed to be idempotent and can be run repeatedly without side effects.

## Important Implementation Details

- **Namespace Convention**: All functions and variables use `lacy_shell_` prefix
- **Error Handling**: 30-second timeout on AI calls with automatic fallback
- **Emergency Bypass**: Commands prefixed with `!` bypass AI processing
- **State Files**: Located in `/tmp/` for MCP PIDs, `$HOME/` for mode persistence
- **Streaming Responses**: AI responses use typewriter effect for better UX
- **Compatibility**: Designed to work alongside oh-my-zsh, starship, and other zsh frameworks

## Development Guidelines

1. **Module Independence**: Each lib/*.zsh file should be self-contained
2. **Function Naming**: Always prefix with `lacy_shell_`
3. **Error Messages**: Include actionable solutions when reporting errors
4. **Testing**: Add tests for any new functionality in appropriate test file
5. **Documentation**: Update relevant docs when adding features
6. **Backward Compatibility**: Maintain compatibility with existing configurations