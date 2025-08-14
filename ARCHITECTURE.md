# Lacy Shell Architecture

This document provides a technical deep dive into Lacy Shell's architecture, design decisions, and implementation details.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Terminal                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │ User Input
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Lacy Shell Plugin                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Key Binding │  │   Input     │  │      Mode Manager       │  │
│  │   Handler   │  │ Interceptor │  │   (shell/agent/auto)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│         │                 │                        │           │
│         └─────────────────┼────────────────────────┘           │
│                           ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Smart Detection Engine                     │   │
│  │        (Keywords, Patterns, Context Analysis)          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                    │
│                           ▼                                    │
│  ┌─────────────┐                           ┌─────────────────┐ │
│  │   Shell     │                           │   AI Agent     │ │
│  │ Execution   │                           │   Processing    │ │
│  └─────────────┘                           └─────────────────┘ │
│         │                                           │         │
│         ▼                                           ▼         │
│  ┌─────────────┐                           ┌─────────────────┐ │
│  │   System    │                           │  MCP Servers   │ │
│  │  Commands   │                           │ (FS/Web/Git)   │ │
│  └─────────────┘                           └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                      │                           │
                      ▼                           ▼
              ┌─────────────┐           ┌─────────────────────┐
              │   Command   │           │    AI APIs          │
              │   Output    │           │ (OpenAI/Anthropic)  │
              └─────────────┘           └─────────────────────┘
```

## 🚨 Emergency Recovery System

Built-in safeguards for when things go wrong:

```zsh
# Emergency bypass commands
!ls                    # Force shell execution (bypass agent)
disable_lacy          # Disable input interception entirely  
enable_lacy           # Re-enable input interception

# Diagnostic commands
mcp_check             # Verify MCP package dependencies
mode status           # Show mode state and persistence info
mcp_logs filesystem   # Check server error logs
```

**Recovery Philosophy:**
- Multiple escape routes for every failure mode
- Clear error messages with actionable solutions
- Graceful degradation when services unavailable
- Never leave user in unrecoverable state

## 🔧 Core Components

### 1. Plugin Entry Point (`lacy-shell.plugin.zsh`)

The main plugin file that orchestrates the entire system:

```zsh
# Hook Integration
zle -N accept-line lacy_shell_smart_accept_line
precmd_functions+=(lacy_shell_precmd)

# Initialization
lacy_shell_init() {
    lacy_shell_load_config
    lacy_shell_setup_keybindings
    lacy_shell_init_mcp
    lacy_shell_setup_prompt
    lacy_shell_set_mode "${LACY_SHELL_DEFAULT_MODE:-auto}"
}
```

**Key Responsibilities:**
- Load and initialize all modules
- Set up zsh hooks and widgets
- Manage plugin lifecycle

### 2. Input Interception (`lib/execute.zsh`)

Intercepts user input using zsh's widget system with robust error handling:

```zsh
lacy_shell_smart_accept_line() {
    local input="$BUFFER"
    
    # Emergency bypass: !command forces shell execution
    if [[ "$input" == !* ]]; then
        BUFFER="${input#!}"
        zle .accept-line
        return
    fi
    
    local execution_mode=$(lacy_shell_detect_mode "$input")
    
    case "$execution_mode" in
        "agent")
            # Validate API keys before proceeding
            if ! lacy_shell_check_api_keys >/dev/null 2>&1; then
                echo "⚠️ No API keys - executing as shell command"
                zle .accept-line
                return
            fi
            
            BUFFER=""  # Clear line
            zle .accept-line
            lacy_shell_execute_agent "$input"
            ;;
        *)
            zle .accept-line  # Normal execution
            ;;
    esac
}
```

**Error Handling Features:**
- 30-second timeout on AI calls
- API key validation before agent execution
- Emergency bypass with `!command` prefix
- Graceful fallback to shell execution

**Design Decision:** Using `accept-line` widget override instead of `preexec` hook provides:
- Better control over command execution
- Ability to prevent shell execution for agent queries
- Clean integration with zsh's line editor

### 3. Mode Management (`lib/modes.zsh`)

Manages the three operational modes:

```zsh
# Mode State
LACY_SHELL_CURRENT_MODE="auto"
LACY_SHELL_MODES=("shell" "agent" "auto")

# Mode Indicators
lacy_shell_get_mode_indicator() {
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell") echo "%F{green}$%f" ;;
        "agent") echo "%F{blue}?%f" ;;
        "auto")  echo "%F{yellow}~%f" ;;
    esac
}
```

**State Management:**
- Global mode variable (`LACY_SHELL_CURRENT_MODE`)
- Visual indicators updated via prompt hooks
- Thread-safe mode transitions

### 4. Smart Detection (`lib/detection.zsh`)

The core intelligence for auto-mode routing:

```zsh
lacy_shell_should_use_agent() {
    local input="$1"
    local input_lower="${input:l}"
    
    # Check for shell commands first
    local first_word="${input%% *}"
    for cmd in "${LACY_SHELL_SHELL_COMMANDS[@]}"; do
        if [[ "$first_word_lower" == "$cmd" ]]; then
            return 1  # Use shell
        fi
    done
    
    # Check for agent keywords
    for keyword in "${LACY_SHELL_AGENT_KEYWORDS[@]}"; do
        if [[ "$input_lower" == *"$keyword"* ]]; then
            return 0  # Use agent
        fi
    done
    
    # Additional heuristics...
}
```

**Detection Algorithm:**
1. **Command Prefix Check** - Known shell commands (ls, git, npm)
2. **Keyword Matching** - Agent keywords (help, how, what)
3. **Pattern Analysis** - Question marks, natural language patterns
4. **Complexity Analysis** - Length, word count, structure
5. **Default Fallback** - Conservative approach (prefer shell)

### 5. AI Integration (`lib/mcp.zsh`)

Handles AI API communication with streaming support:

```zsh
lacy_shell_query_agent() {
    # Build context with conversation history
    cat > "$temp_file" << EOF
System Context:
- Current Directory: $(pwd)
- Current Date: $(date)
- User: $USER

Recent Conversation:
$(tail -20 "$LACY_SHELL_CONVERSATION_FILE" 2>/dev/null)

Current Query: $query
EOF
    
    # Stream response and save to history
    local response=$(lacy_shell_send_to_ai_streaming "$temp_file" "$query")
}
```

**Streaming Implementation:**
```python
# Character-by-character streaming
for char in content:
    print(char, end='', flush=True)
    time.sleep(0.008)  # Typewriter effect
```

### 6. Configuration Management (`lib/config.zsh`)

Handles YAML configuration with fallback parsing:

```zsh
lacy_shell_load_config() {
    # Try PyYAML first, fallback to simple parser
    if command -v python3 >/dev/null 2>&1; then
        eval "$(python3 -c "
try:
    import yaml
    # Full YAML parsing
except ImportError:
    # Simple line-by-line fallback
    # Handles basic key: value pairs
")"
    fi
}
```

**Configuration Strategy:**
- YAML for user-friendliness
- Python parsing for robustness
- Fallback parser for minimal environments
- Environment variables for runtime access

## 🔄 Data Flow

### 1. User Input Flow

```
User Types → ZSH Line Editor → accept-line Widget → Mode Detection
    ↓                                                       ↓
Shell Execution ←─ Shell Mode ←─ Mode Router ─→ Agent Mode → AI Processing
    ↓                                                       ↓
Command Output                                         Streamed Response
```

### 2. Configuration Flow

```
config.yaml → Python Parser → Environment Variables → Runtime Components
     ↓              ↓                    ↓                    ↓
API Keys    →   JSON Payload   →   curl Request   →   AI Response
MCP Servers →   Server Config  →   Process Start  →   Tool Access
Detection   →   Keyword Lists  →   Pattern Match  →   Mode Decision
```

### 3. Conversation Flow

```
User Query → Context Builder → API Request → Streaming Response
     ↓             ↓                           ↓
History File ← Response Storage ←──────────────┘
     ↓
Next Query Context
```

## 🎯 Design Patterns

### 1. Plugin Architecture

**Modular Design:**
- Each `lib/*.zsh` file is a self-contained module
- Clear separation of concerns
- Minimal inter-module dependencies

**Namespace Management:**
- All functions prefixed with `lacy_shell_`
- Global variables prefixed with `LACY_SHELL_`
- Consistent naming conventions

### 2. Hook-Based Integration

**ZSH Integration:**
```zsh
# Widget override for input interception
zle -N accept-line lacy_shell_smart_accept_line

# Prompt integration
precmd_functions+=(lacy_shell_update_prompt)

# Cleanup on exit
trap lacy_shell_cleanup EXIT
```

**Benefits:**
- Non-invasive integration
- Easy to disable/remove
- Compatible with other plugins

### 3. State Management

**Mode State:**
- Single source of truth (`LACY_SHELL_CURRENT_MODE`)
- Atomic state transitions
- Visual feedback via prompt

**Conversation State:**
- Persistent file-based storage
- Automatic cleanup (size limits)
- Context window management

### 4. Error Handling

**Graceful Degradation:**
```zsh
# API failure fallback
if ! lacy_shell_query_agent "$query"; then
    echo "AI unavailable. Try: $query"
    # Suggest shell alternative
fi

# Configuration errors
if ! lacy_shell_load_config; then
    echo "Using default configuration"
    # Continue with defaults
fi
```

## 🚀 Performance Considerations

### 1. Startup Performance

**Lazy Loading:**
- Heavy operations deferred until needed
- MCP servers started on demand
- API connections established lazily

**Caching:**
- Configuration parsed once at startup
- Detection patterns compiled once
- Conversation history loaded incrementally

### 2. Runtime Performance

**Input Processing:**
- O(1) mode checking
- O(n) keyword matching (where n = small keyword set)
- Short-circuit evaluation for common patterns

**Memory Management:**
- Conversation history size limits
- Temporary file cleanup
- Minimal global state

### 3. Network Performance

**API Optimization:**
- Connection reuse where possible
- Timeout handling
- Streaming for real-time feedback

## 🔒 Security Model

### 1. API Key Management

**Storage:**
- Local file-based storage
- No network transmission except to APIs
- User-controlled access permissions

**Usage:**
- Keys loaded into environment variables
- Validated before use
- Never logged or exposed

### 2. Command Execution

**Shell Commands:**
- Normal zsh execution path
- No privilege escalation
- User's existing permissions

**AI-Generated Commands:**
- Not automatically executed
- User must explicitly run suggestions
- Clear distinction between advice and execution

### 3. Data Privacy

**Conversation Data:**
- Stored locally only
- User can clear at any time
- Not transmitted except as context to AI APIs

**System Information:**
- Minimal context (current directory, user, date)
- No sensitive environment variables
- User-configurable context sharing

## 🧪 Testing Strategy

### 1. Unit Testing

**Component Tests:**
```bash
# Detection algorithm tests
test_detection_shell_commands
test_detection_agent_keywords
test_detection_edge_cases

# Mode switching tests
test_mode_transitions
test_mode_indicators
test_keybinding_handlers
```

### 2. Integration Testing

**End-to-End Tests:**
```bash
# Full workflow tests
test_auto_mode_routing
test_agent_conversation_flow
test_shell_command_execution
```

### 3. Performance Testing

**Benchmarks:**
- Startup time measurement
- Input processing latency
- Memory usage monitoring

## 🔮 Future Architecture

### 1. Plugin Ecosystem

**Planned Architecture:**
```
Core Lacy Shell
├── Detection Plugins (custom patterns)
├── MCP Server Plugins (specialized tools)
├── Theme Plugins (visual customization)
└── Integration Plugins (external tools)
```

### 2. Machine Learning Integration

**Smart Detection Enhancement:**
- User behavior learning
- Personalized detection patterns
- Confidence-based routing

### 3. Distributed Capabilities

**Team Features:**
- Shared conversation history
- Collaborative debugging
- Knowledge base integration

## 📊 Metrics and Monitoring

### 1. Usage Metrics

**Tracked Data:**
- Mode usage frequency
- Detection accuracy
- Response times
- Error rates

**Privacy-Preserving:**
- Local storage only
- Aggregated statistics
- No personal data transmission

### 2. Performance Metrics

**Key Indicators:**
- Plugin load time
- Input processing latency
- API response times
- Memory usage patterns

This architecture provides a solid foundation for Lacy Shell's current capabilities while maintaining flexibility for future enhancements and integrations.
