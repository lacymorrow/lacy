# Contributing to Lacy Shell

Thank you for your interest in contributing to Lacy Shell! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/lacy-shell.git
   cd lacy-shell
   ```

2. **Development Installation**
   ```bash
   # Install in development mode
   ./install.sh --local
   
   # Or manually link
   ln -sf "$(pwd)/lacy-shell.plugin.zsh" ~/.lacy-shell/lacy-shell.plugin.zsh
   ```

3. **Test Your Changes**
   ```bash
   # Run tests
   ./test.sh
   
   # Test specific functionality
   lacy_shell_test_detection
   lacy_shell_test_mcp
   ```

### Development Workflow

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Follow the coding standards below
   - Test your changes thoroughly
   - Update documentation as needed

3. **Submit a Pull Request**
   - Write clear commit messages
   - Include tests for new functionality
   - Update relevant documentation

## 📁 Project Structure

```
lacy-shell/
├── lacy-shell.plugin.zsh    # Main entry point
├── lib/                     # Core modules
│   ├── config.zsh          # Configuration management
│   ├── modes.zsh           # Mode switching logic
│   ├── mcp.zsh             # AI integration & MCP
│   ├── detection.zsh       # Auto-detection algorithms
│   ├── keybindings.zsh     # Keyboard shortcuts
│   ├── prompt.zsh          # Visual indicators
│   └── execute.zsh         # Command execution
├── install.sh              # Installation script
├── test.sh                 # Test suite
├── README.md               # Main documentation
├── EXAMPLES.md             # Usage examples
└── docs/                   # Additional documentation
```

## 🛠️ Coding Standards

### Shell Scripting Guidelines

1. **Function Naming**
   ```bash
   # Use lacy_shell_ prefix for all functions
   lacy_shell_your_function() {
       # Function body
   }
   ```

2. **Variable Naming**
   ```bash
   # Use UPPERCASE for constants
   LACY_SHELL_VERSION="1.0.0"
   
   # Use lowercase for local variables
   local input_text="$1"
   ```

3. **Error Handling**
   ```bash
   # Always check return codes
   if ! command_that_might_fail; then
       echo "Error: Command failed"
       return 1
   fi
   ```

4. **Documentation**
   ```bash
   # Document functions with comments
   # Brief description of what the function does
   # Args:
   #   $1 - First argument description
   # Returns:
   #   0 on success, 1 on error
   lacy_shell_example_function() {
       local arg1="$1"
       # Implementation
   }
   ```

### Code Organization

1. **Keep functions focused** - Each function should do one thing well
2. **Use meaningful names** - Variables and functions should be self-documenting
3. **Minimize global state** - Prefer local variables and function parameters
4. **Handle edge cases** - Consider empty inputs, missing files, etc.

## 🧪 Testing

### Running Tests

```bash
# Run all tests
./test.sh

# Test specific components
zsh -c "source lacy-shell.plugin.zsh && lacy_shell_test_detection"
```

### Writing Tests

When adding new functionality, include tests:

```bash
# Add to test.sh or create component-specific test functions
test_your_feature() {
    echo "Testing your feature..."
    
    # Test setup
    local test_input="example"
    
    # Run test
    local result=$(your_function "$test_input")
    
    # Verify result
    if [[ "$result" == "expected" ]]; then
        echo "✅ Test passed"
    else
        echo "❌ Test failed: expected 'expected', got '$result'"
        return 1
    fi
}
```

## 🎯 Areas for Contribution

### High Priority

1. **MCP Server Integration**
   - Implement real MCP server connections
   - Add more MCP server types
   - Improve error handling

2. **Auto-Detection Improvements**
   - Better natural language detection
   - Machine learning-based classification
   - User-customizable patterns

3. **Performance Optimization**
   - Faster startup times
   - Cached configurations
   - Reduced API calls

### Medium Priority

1. **Shell Compatibility**
   - Fish shell support
   - Bash compatibility layer
   - PowerShell integration

2. **UI Enhancements**
   - Better visual indicators
   - Customizable themes
   - Progress bars for long operations

3. **Documentation**
   - More usage examples
   - Video tutorials
   - API documentation

### Ideas Welcome

1. **Plugin Ecosystem**
   - Custom detection rules
   - Third-party integrations
   - Community plugins

2. **Advanced Features**
   - Command prediction
   - Workflow automation
   - Team collaboration features

## 🐛 Bug Reports

### Before Reporting

1. **Check existing issues** - Search for similar problems
2. **Try latest version** - Update to the latest commit
3. **Test minimal case** - Reproduce with minimal configuration

### Bug Report Template

```markdown
**Bug Description**
A clear description of what the bug is.

**Steps to Reproduce**
1. Run command '...'
2. See error

**Expected Behavior**
What you expected to happen.

**Environment**
- OS: [e.g. macOS 14.0]
- Shell: [e.g. zsh 5.9]
- Terminal: [e.g. iTerm2]
- Lacy Shell version: [e.g. commit hash]

**Configuration**
```yaml
# Your config.yaml (with API keys removed)
```

**Additional Context**
Any other relevant information.
```

## 💡 Feature Requests

### Feature Request Template

```markdown
**Feature Description**
A clear description of the feature you'd like.

**Use Case**
Describe how this feature would be used.

**Proposed Implementation**
If you have ideas about how to implement this.

**Alternatives Considered**
Other ways to achieve the same goal.
```

## 🔒 Security

### Reporting Security Issues

For security vulnerabilities, please email [security@yourproject.com] instead of creating a public issue.

### Security Guidelines

1. **API Key Handling**
   - Never log API keys
   - Store securely in config files
   - Validate before use

2. **Command Execution**
   - Sanitize inputs
   - Validate commands before execution
   - Use safe defaults

## 📝 Documentation

### Documentation Updates

When making changes, update relevant documentation:

1. **README.md** - Main usage documentation
2. **EXAMPLES.md** - Usage examples and recipes
3. **Function comments** - Inline documentation
4. **Configuration** - Update config examples

### Writing Style

1. **Be concise** - Get to the point quickly
2. **Use examples** - Show, don't just tell
3. **Consider all users** - From beginners to experts
4. **Test examples** - Ensure all examples work

## 🏷️ Release Process

### Version Numbering

We use semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR** - Breaking changes
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes

### Release Checklist

1. Update version numbers
2. Update CHANGELOG.md
3. Test on multiple systems
4. Create release notes
5. Tag release
6. Update documentation

## 🤝 Community

### Communication

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - General questions and ideas
- **Pull Requests** - Code contributions

### Code of Conduct

Please be respectful and constructive in all interactions. We want Lacy Shell to be welcoming to contributors of all backgrounds and experience levels.

## 🙏 Recognition

Contributors will be recognized in:
- README.md acknowledgments
- Release notes
- Project documentation

Thank you for helping make Lacy Shell better! 🚀
