# Lacy Shell API Documentation

This document covers the public API, functions, and interfaces available in Lacy Shell.

## 🔧 Public Functions

### Mode Management

#### `lacy_shell_set_mode(mode)`
Sets the current operational mode.

**Parameters:**
- `mode` (string): One of "shell", "agent", or "auto"

**Returns:**
- 0 on success, 1 on invalid mode

**Example:**
```bash
lacy_shell_set_mode "agent"
lacy_shell_set_mode "auto"
```

#### `lacy_shell_get_mode()`
Returns the current mode.

**Returns:**
- String: Current mode ("shell", "agent", "auto")

**Example:**
```bash
current_mode=$(lacy_shell_get_mode)
echo "Current mode: $current_mode"
```

#### `lacy_shell_toggle_mode()`
Cycles through modes in order: auto → shell → agent → auto.

**Example:**
```bash
lacy_shell_toggle_mode
```

### AI Interaction

#### `lacy_shell_query_agent(query, [use_mcp])`
Sends a query to the AI agent with full context.

**Parameters:**
- `query` (string): The question or request
- `use_mcp` (boolean, optional): Whether to include MCP context (default: true)

**Returns:**
- 0 on success, 1 on error

**Example:**
```bash
lacy_shell_query_agent "What files were modified today?"
lacy_shell_query_agent "Help me debug this error" false
```

### Configuration

#### `lacy_shell_load_config()`
Loads configuration from `~/.lacy-shell/config.yaml`.

**Returns:**
- 0 on success, 1 on error

**Side Effects:**
- Sets environment variables from config
- Updates global configuration state

#### `lacy_shell_get_config(key)`
Retrieves a configuration value.

**Parameters:**
- `key` (string): Configuration key

**Returns:**
- String: Configuration value or empty string

**Example:**
```bash
default_mode=$(lacy_shell_get_config "modes.default")
```

#### `lacy_shell_check_api_keys()`
Verifies that API keys are configured.

**Returns:**
- 0 if keys are available, 1 if missing

### Detection and Routing

#### `lacy_shell_detect_mode(input)`
Determines the appropriate mode for given input.

**Parameters:**
- `input` (string): User input to analyze

**Returns:**
- String: Recommended mode ("shell" or "agent")

**Example:**
```bash
mode=$(lacy_shell_detect_mode "what is this file?")
echo "Detected mode: $mode"  # Output: agent
```

#### `lacy_shell_should_use_agent(input)`
Checks if input should be routed to the agent.

**Parameters:**
- `input` (string): User input to analyze

**Returns:**
- 0 if agent should be used, 1 if shell should be used

### Conversation Management

#### `lacy_shell_clear_conversation()`
Clears the conversation history.

**Side Effects:**
- Removes `~/.lacy-shell/conversation.log`

#### `lacy_shell_show_conversation()`
Displays the conversation history.

**Output:**
- Prints conversation history to stdout

### Testing and Debugging

#### `lacy_shell_test_detection()`
Runs detection algorithm tests with sample inputs.

**Output:**
- Prints test results showing input → detected mode

#### `lacy_shell_test_mcp()`
Tests MCP configuration and API connectivity.

**Returns:**
- 0 if tests pass, 1 if tests fail

**Output:**
- Status of MCP servers and API keys

## 🎮 Command Aliases

### User-Facing Commands

#### `ask "question"`
Direct AI query without mode switching.

**Example:**
```bash
ask "How do I use git rebase?"
ask "Explain this error message"
```

#### `mode [shell|agent|auto|toggle|help]`
User-friendly mode switching command.

**Examples:**
```bash
mode shell      # Switch to shell mode
mode agent      # Switch to agent mode
mode auto       # Switch to auto mode
mode toggle     # Toggle to next mode
mode help       # Show mode information
```

#### `clear_chat`
Alias for `lacy_shell_clear_conversation()`.

#### `show_chat`
Alias for `lacy_shell_show_conversation()`.

### Shorthand Aliases

```bash
mode s    # shell mode
mode a    # agent mode  
mode u    # auto mode
mode t    # toggle mode
```

## 🎯 Keybinding API

### Primary Keybindings

| Key Combination | Function | Description |
|-----------------|----------|-------------|
| `Ctrl+Space` | `lacy_shell_toggle_mode_widget` | Toggle mode (primary) |
| `Ctrl+T` | `lacy_shell_toggle_mode_widget` | Toggle mode (backup) |
| `Ctrl+X Ctrl+A` | `lacy_shell_agent_mode_widget` | Switch to agent mode |
| `Ctrl+X Ctrl+S` | `lacy_shell_shell_mode_widget` | Switch to shell mode |
| `Ctrl+X Ctrl+U` | `lacy_shell_auto_mode_widget` | Switch to auto mode |
| `Ctrl+X Ctrl+H` | `lacy_shell_help_widget` | Show help |

### Widget Functions

#### `lacy_shell_toggle_mode_widget()`
ZLE widget that toggles mode and updates prompt.

#### `lacy_shell_agent_mode_widget()`
ZLE widget that switches to agent mode.

#### `lacy_shell_shell_mode_widget()`
ZLE widget that switches to shell mode.

#### `lacy_shell_auto_mode_widget()`
ZLE widget that switches to auto mode.

#### `lacy_shell_help_widget()`
ZLE widget that displays help information.

## 🔧 Configuration API

### Configuration Structure

```yaml
api_keys:
  openai: "string"
  anthropic: "string"

mcp:
  servers:
    - name: "string"
      command: "string" 
      args: ["array", "of", "strings"]

modes:
  default: "string"  # shell|agent|auto

detection:
  agent_keywords:
    - "array"
    - "of" 
    - "strings"
  shell_commands:
    - "array"
    - "of"
    - "strings"

keybindings:
  toggle_mode: "string"
  agent_mode: "string"
  shell_mode: "string"
```

### Environment Variables

These variables are set automatically from configuration:

| Variable | Description | Example |
|----------|-------------|---------|
| `LACY_SHELL_API_OPENAI` | OpenAI API key | `sk-...` |
| `LACY_SHELL_API_ANTHROPIC` | Anthropic API key | `sk-ant-...` |
| `LACY_SHELL_CURRENT_MODE` | Current mode | `auto` |
| `LACY_SHELL_DEFAULT_MODE` | Default mode | `auto` |
| `LACY_SHELL_MCP_SERVERS` | MCP server config flag | `configured` |

## 🔌 Extension Points

### Custom Detection Rules

You can extend detection by modifying arrays:

```bash
# Add custom agent keywords
LACY_SHELL_AGENT_KEYWORDS+=("debug" "analyze" "optimize")

# Add custom shell commands  
LACY_SHELL_SHELL_COMMANDS+=("mycommand" "customtool")
```

### Custom MCP Servers

Add servers to configuration:

```yaml
mcp:
  servers:
    - name: "custom-server"
      command: "/path/to/server"
      args: ["--option", "value"]
```

### Prompt Integration

#### `lacy_shell_get_mode_indicator()`
Returns formatted mode indicator for prompts.

**Returns:**
- String: Colored mode indicator

**Example:**
```bash
# In prompt setup
PS1="$(lacy_shell_get_mode_indicator) $PS1"
```

#### `lacy_shell_get_mode_text()`
Returns plain text mode indicator.

**Returns:**
- String: Mode name in uppercase

## 🚀 Hooks and Events

### Lifecycle Hooks

#### `lacy_shell_init()`
Called when plugin is loaded.

**Side Effects:**
- Loads configuration
- Sets up keybindings  
- Initializes MCP
- Sets default mode

#### `lacy_shell_cleanup()`
Called when plugin is unloaded.

**Side Effects:**
- Cleans up MCP connections
- Unsets variables

### ZSH Integration Hooks

#### `lacy_shell_smart_accept_line()`
Overrides zsh's `accept-line` widget.

**Behavior:**
- Intercepts user input
- Routes to agent or shell based on mode
- Provides streaming responses

#### `lacy_shell_precmd()`
Called before each prompt display.

**Behavior:**
- Updates prompt with current mode
- Manages visual indicators

## 🧪 Testing API

### Test Functions

#### `lacy_shell_test_detection()`
Tests auto-detection with predefined inputs.

**Test Cases:**
- Shell commands (ls, git, npm)
- Agent queries (help, how, what)
- Edge cases (empty, complex)

#### `lacy_shell_test_mcp()`
Tests MCP configuration and connectivity.

**Checks:**
- API key availability
- MCP server configuration
- Basic connectivity

### Custom Testing

```bash
# Test specific detection
test_input="your test case"
result=$(lacy_shell_detect_mode "$test_input")
echo "Input: $test_input → Mode: $result"

# Test mode switching
lacy_shell_set_mode "agent"
current=$(lacy_shell_get_mode)
[[ "$current" == "agent" ]] && echo "✅ Mode switch worked"
```

## 🔒 Security API

### Safe Functions

These functions are safe to call and don't execute arbitrary code:

- `lacy_shell_get_mode()`
- `lacy_shell_detect_mode()`
- `lacy_shell_get_config()`
- `lacy_shell_test_detection()`

### Sensitive Functions

These functions access external resources:

- `lacy_shell_query_agent()` - Makes API calls
- `lacy_shell_load_config()` - Reads configuration files
- `lacy_shell_init_mcp()` - Starts external processes

## 📝 Error Handling

### Return Codes

- **0** - Success
- **1** - General error
- **2** - Configuration error
- **3** - API error
- **4** - MCP error

### Error Messages

Functions output errors to stderr with prefixes:

- `Error:` - Critical errors
- `Warning:` - Non-critical issues
- `Debug:` - Debug information (if enabled)

### Error Recovery

```bash
# Graceful error handling
if ! lacy_shell_query_agent "$query"; then
    echo "AI unavailable. Falling back to shell."
    # Execute as shell command
fi
```

### Emergency Functions

#### `lacy_shell_disable_interception()`
Disables input interception for troubleshooting.

**Usage:**
```bash
lacy_shell_disable_interception  # or: disable_lacy
```

#### `lacy_shell_enable_interception()`
Re-enables input interception.

**Usage:**
```bash
lacy_shell_enable_interception   # or: enable_lacy
```

### Diagnostic Functions

#### `lacy_shell_check_mcp_packages()`
Verifies MCP package dependencies are installed.

**Returns:**
- 0 if all packages available, 1 if missing

**Usage:**
```bash
if lacy_shell_check_mcp_packages; then
    echo "MCP packages ready"
else
    echo "Missing MCP packages"
fi
```

#### `lacy_shell_mode_status()`
Shows detailed mode information.

**Output:**
- Current mode
- Default mode  
- Saved mode
- Mode file location

## 🔗 Integration Examples

### Custom Prompts

```bash
# Starship integration
function lacy_mode() {
    echo "$(lacy_shell_get_mode_indicator)"
}

# Oh-My-Zsh theme
PROMPT='$(lacy_shell_get_mode_indicator) '$PROMPT
```

### Custom Scripts

```bash
#!/usr/bin/env zsh
# smart-command.sh

source ~/.lacy-shell/lacy-shell.plugin.zsh

input="$1"
mode=$(lacy_shell_detect_mode "$input")

if [[ "$mode" == "agent" ]]; then
    lacy_shell_query_agent "$input"
else
    eval "$input"
fi
```

This API documentation provides comprehensive coverage of Lacy Shell's programmatic interfaces for users and developers building extensions or integrations.
