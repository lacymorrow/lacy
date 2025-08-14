# Lacy Shell Examples & Recipes

This comprehensive guide provides real-world examples, use cases, and recipes for getting the most out of Lacy Shell.

## 🚀 Quick Start Examples

After installation, try these examples to get familiar with the three modes:

### Shell Mode Examples
```bash
# Switch to shell mode
[SHELL] → ls -la
[SHELL] → git status
[SHELL] → npm install
[SHELL] → cd /path/to/project
```

### Agent Mode Examples
```bash
# Switch to agent mode (Ctrl+A)
[AGENT] → What files were modified in the last week?
[AGENT] → Help me write a Python script to process CSV files
[AGENT] → Explain what this git repository does
[AGENT] → How do I optimize this React component?
[AGENT] → Find all TODO comments in my code
```

### Auto Mode Examples
```bash
# Auto mode detects intent automatically
[AUTO] → ls -la                           # → Shell execution
[AUTO] → what files are in this directory # → Agent response
[AUTO] → git commit -m "fix bug"          # → Shell execution  
[AUTO] → how do I revert last commit      # → Agent response
[AUTO] → npm test                         # → Shell execution
[AUTO] → explain this error message       # → Agent response
```

## Keybinding Examples

### Mode Switching
- `Alt+Enter`: Cycle through modes (shell → agent → auto → shell...)
- `Ctrl+A`: Direct switch to Agent mode
- `Ctrl+S`: Direct switch to Shell mode  
- `Alt+A`: Direct switch to Auto mode
- `Alt+H`: Show help

### Example Workflow
```bash
# Start in auto mode
[AUTO] → ls
# Files are listed normally

# Switch to agent mode for help
# Press Ctrl+A
[AGENT] → how do I find large files?
# AI explains: "You can use the 'find' command with size parameters..."

# Switch back to shell to execute the suggestion
# Press Ctrl+S  
[SHELL] → find . -size +100M
```

## Advanced Usage

### Using Built-in Aliases
```bash
# Direct AI queries (works in any mode)
ask "what's the difference between git merge and rebase?"

# Get help with context
aihelp "docker compose"

# AI-powered command completion
aicomplete "git log --"

# Search command history with AI
hisearch "deploy"
```

### Configuration Examples

#### Basic API Setup
```yaml
# ~/.lacy-shell/config.yaml
api_keys:
  openai: "sk-your-openai-key-here"
  # or
  anthropic: "your-anthropic-key-here"

modes:
  default: "auto"
```

#### Advanced MCP Configuration
```yaml
mcp:
  servers:
    - name: "filesystem"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/Users/username/projects"]
    - name: "web"
      command: "npx"
      args: ["@modelcontextprotocol/server-web"]
    - name: "git"
      command: "npx" 
      args: ["@modelcontextprotocol/server-git", "--repository", "."]
```

#### Custom Detection Keywords
```yaml
detection:
  agent_keywords:
    - "help"
    - "explain"
    - "what"
    - "how"
    - "debug"
    - "analyze"
    - "optimize"
    - "tutorial"
  
  shell_commands:
    - "ls"
    - "cd"
    - "git"
    - "npm"
    - "docker"
    - "kubectl"
    - "terraform"
```

## Integration Examples

### With Starship Prompt
The mode indicator automatically integrates with Starship:
```bash
❯ [AUTO] your-command-here
```

### With Oh My Zsh
Works seamlessly with existing Oh My Zsh themes:
```bash
➜ project git:(main) [AGENT] help me with this error
```

### With tmux
Use in tmux sessions for enhanced development workflow:
```bash
# Terminal 1: Development 
[AUTO] → npm run dev

# Terminal 2: AI assistance
[AGENT] → explain this error in the logs

# Terminal 3: Shell operations
[SHELL] → git add . && git commit
```

## Real-world Scenarios

### Debugging Workflow
```bash
# Start with an error
[AUTO] → npm test
# Test fails...

# Get AI help
[AGENT] → This test is failing with "Cannot read property 'id' of undefined". How do I debug this?
# AI suggests debugging steps...

# Execute suggestions  
[SHELL] → node --inspect-brk ./node_modules/.bin/jest specific-test.js
```

### DevOps Tasks
```bash
# Check system status
[AUTO] → docker ps
# Shows running containers

# Ask for optimization advice
[AGENT] → My Docker containers are using too much memory. How can I optimize them?
# AI provides specific recommendations...

# Apply suggestions
[SHELL] → docker system prune
[SHELL] → docker build --memory=512m .
```

### Learning New Technologies  
```bash
# Explore a new project
[AUTO] → ls
# See project structure

# Get oriented
[AGENT] → This looks like a Rust project. Can you explain the structure and how to get started?
# AI explains Cargo.toml, src/ directory, etc...

# Follow AI guidance
[SHELL] → cargo build
[SHELL] → cargo test
```

## Troubleshooting Examples

### Test Detection Logic
```bash
lacy_shell_test_detection
```

### Check Configuration
```bash
lacy_shell_test_mcp
```

### Debug Mode Issues
```bash
# Check current mode
echo $LACY_SHELL_CURRENT_MODE

# Manually test mode switching
lacy_shell_set_mode "agent"
lacy_shell_set_mode "shell" 
lacy_shell_set_mode "auto"
```

### API Key Issues
```bash
# Check if keys are loaded
env | grep LACY_SHELL_API

# Test AI connectivity
ask "hello"
```

## Tips and Best Practices

1. **Start with Auto Mode**: Let the system learn your patterns
2. **Use Agent Mode for Learning**: Great for exploring new technologies
3. **Shell Mode for Precision**: When you know exactly what command to run
4. **Combine with Existing Tools**: Works great with your current shell setup
5. **Customize Detection**: Adjust keywords based on your workflow

## 💼 Professional Workflows

### Web Development
```bash
# Starting a new project
~ ❯ create a new React TypeScript project
AI: I'll help you create a new React TypeScript project...

~ ❯ npx create-react-app my-app --template typescript
# Executes normally

~ ❯ what are the best practices for React TypeScript?
AI: Here are the key best practices for React with TypeScript...

~ ❯ cd my-app && npm start
# Executes normally
```

### DevOps & Infrastructure
```bash
# Docker troubleshooting
~ ❯ docker ps
# Shows containers

~ ❯ my container keeps crashing, how do I debug?
AI: To debug a crashing Docker container, try these steps...

~ ❯ docker logs container-name
# Shows logs

~ ❯ explain this error message: "ECONNREFUSED"
AI: ECONNREFUSED means the connection was actively refused...
```

### Data Science & Analytics
```bash
# Data analysis workflow
~ ❯ help me analyze a CSV file with pandas
AI: Here's how to analyze CSV data with pandas...

~ ❯ python -c "import pandas as pd; df = pd.read_csv('data.csv'); print(df.head())"
# Executes Python command

~ ❯ the data has missing values, what should I do?
AI: For handling missing values in pandas, you have several options...

~ ❯ jupyter notebook
# Starts Jupyter
```

## 🛠️ Development Scenarios

### Git Workflow Assistance
```bash
# Complex git operations
~ ❯ git status
# Shows current status

~ ❯ I accidentally committed to the wrong branch, help me fix it
AI: To move commits to the correct branch, you can use...

~ ❯ git log --oneline -5
# Shows recent commits

~ ❯ git cherry-pick abc123
# Executes suggested command
```

### Code Review & Debugging
```bash
# Code understanding
~ ❯ cat complex_function.py
# Shows file contents

~ ❯ explain what this function does
AI: This function appears to be implementing a binary search algorithm...

~ ❯ how can I optimize this code?
AI: Here are several ways to optimize this function...

~ ❯ grep -n "TODO" *.py
# Finds TODO comments
```

### API Development
```bash
# API testing and development
~ ❯ curl -X GET http://localhost:3000/api/users
# Tests API endpoint

~ ❯ the API returns 500 error, help me debug
AI: A 500 error indicates a server-side issue. Check these areas...

~ ❯ tail -f /var/log/app.log
# Monitors logs

~ ❯ explain REST API best practices
AI: Here are the key REST API best practices...
```

## 🎯 Learning & Education

### Programming Tutorial Assistant
```bash
# Learning new languages
~ ❯ I want to learn Rust, where should I start?
AI: Great choice! Here's a structured approach to learning Rust...

~ ❯ cargo new hello_rust
# Creates new Rust project

~ ❯ explain Rust ownership and borrowing
AI: Rust's ownership system is unique among programming languages...

~ ❯ cargo run
# Runs the Rust program
```

### Command Line Mastery
```bash
# Learning shell commands
~ ❯ find . -name "*.js" -type f
# Finds JavaScript files

~ ❯ explain this find command
AI: This find command searches for JavaScript files. Here's how it works...

~ ❯ how do I find files modified in the last 24 hours?
AI: To find recently modified files, use the -mtime option...

~ ❯ find . -mtime -1 -type f
# Executes suggested command
```

## 🔧 System Administration

### Server Management
```bash
# Server monitoring and maintenance
~ ❯ top
# Shows system processes

~ ❯ the server is using 90% CPU, what should I check?
AI: High CPU usage can be caused by several factors...

~ ❯ ps aux | sort -nrk 3,3 | head -5
# Shows top CPU processes

~ ❯ systemctl status nginx
# Checks service status
```

### Network Diagnostics
```bash
# Network troubleshooting
~ ❯ ping google.com
# Tests connectivity

~ ❯ connection is slow, how do I diagnose network issues?
AI: Network slowness can be diagnosed with these tools...

~ ❯ traceroute google.com
# Traces network path

~ ❯ netstat -tulpn | grep :80
# Checks port 80
```

## 📊 Data Processing

### Log Analysis
```bash
# Analyzing log files
~ ❯ tail -100 /var/log/nginx/access.log
# Shows recent log entries

~ ❯ help me analyze these nginx logs for errors
AI: To analyze nginx logs effectively, look for these patterns...

~ ❯ grep "ERROR" /var/log/nginx/error.log | tail -10
# Finds recent errors

~ ❯ awk '{print $1}' access.log | sort | uniq -c | sort -nr
# Counts unique IPs
```

### File Processing
```bash
# Text processing tasks
~ ❯ ls -la *.csv
# Lists CSV files

~ ❯ how do I merge multiple CSV files?
AI: To merge CSV files, you can use several approaches...

~ ❯ cat *.csv > merged_data.csv
# Simple concatenation

~ ❯ how do I remove duplicates from this merged file?
AI: To remove duplicates from a CSV file...
```

## 🚀 Automation & Scripting

### Bash Script Development
```bash
# Creating automation scripts
~ ❯ help me write a backup script
AI: Here's a robust backup script template...

~ ❯ nano backup.sh
# Edit the script

~ ❯ chmod +x backup.sh
# Make executable

~ ❯ how do I schedule this with cron?
AI: To schedule scripts with cron...
```

### Deployment Automation
```bash
# Deployment workflows
~ ❯ docker build -t myapp:latest .
# Builds Docker image

~ ❯ help me create a CI/CD pipeline
AI: Here's how to set up a CI/CD pipeline...

~ ❯ kubectl apply -f deployment.yaml
# Deploys to Kubernetes

~ ❯ explain Kubernetes deployment strategies
AI: Kubernetes offers several deployment strategies...
```

## 🎨 Creative & Content

### Documentation Generation
```bash
# Documentation workflows
~ ❯ ls *.md
# Lists markdown files

~ ❯ help me improve this README file
AI: Here are ways to enhance your README...

~ ❯ pandoc README.md -o README.pdf
# Converts markdown to PDF

~ ❯ what are markdown best practices?
AI: Here are markdown best practices for documentation...
```

### Content Processing
```bash
# Content management
~ ❯ find . -name "*.jpg" -type f
# Finds image files

~ ❯ how do I batch resize these images?
AI: To batch resize images, you can use ImageMagick...

~ ❯ mogrify -resize 50% *.jpg
# Resizes images

~ ❯ how do I optimize images for web?
AI: Web image optimization involves...
```

## 🔍 Debugging & Troubleshooting

### Application Debugging
```bash
# Debugging workflows
~ ❯ python app.py
# Runs application (may show error)

~ ❯ I'm getting a "ModuleNotFoundError", how do I fix it?
AI: ModuleNotFoundError typically means...

~ ❯ pip list | grep module-name
# Checks if module is installed

~ ❯ python -m pip install module-name
# Installs missing module
```

### Performance Analysis
```bash
# Performance monitoring
~ ❯ time ./my-script.sh
# Measures execution time

~ ❯ this script is slow, how do I profile it?
AI: To profile shell scripts and find bottlenecks...

~ ❯ strace -c ./my-script.sh
# System call analysis

~ ❯ how do I optimize shell script performance?
AI: Shell script optimization techniques include...
```

## 💡 Advanced Use Cases

### Machine Learning Workflows
```bash
# ML development
~ ❯ python train_model.py
# Trains ML model

~ ❯ my model accuracy is only 60%, how can I improve it?
AI: Low model accuracy can be improved through...

~ ❯ tensorboard --logdir=logs
# Starts TensorBoard

~ ❯ explain overfitting and how to prevent it
AI: Overfitting occurs when a model...
```

### Security & Compliance
```bash
# Security analysis
~ ❯ nmap -sP 192.168.1.0/24
# Network scan

~ ❯ help me secure this server
AI: Server security involves multiple layers...

~ ❯ fail2ban-client status
# Checks fail2ban status

~ ❯ what are the essential security tools for Linux?
AI: Essential Linux security tools include...
```

## 🎮 Gaming & Entertainment

### Game Development
```bash
# Game dev workflow
~ ❯ ls game_assets/
# Lists game files

~ ❯ how do I optimize game sprites?
AI: Game sprite optimization involves...

~ ❯ ffmpeg -i sprite.png -vf scale=50% optimized_sprite.png
# Optimizes sprite

~ ❯ explain game development best practices
AI: Game development best practices include...
```

## 💬 Conversation Examples

### Context Awareness
```bash
# Multi-turn conversation
? ❯ I'm working on a web app with Node.js and React
AI: Great! What specific aspect of your Node.js/React app are you working on?

? ❯ the API is slow
AI: For your Node.js API performance issues, let's investigate...

? ❯ what profiling tools did you mention?
AI: I mentioned clinic.js and 0x for Node.js profiling...

? ❯ how do I install clinic?
AI: Install clinic.js with: npm install -g clinic
```

### Learning Progression
```bash
# Building knowledge over time
? ❯ I'm new to Docker
AI: Welcome to Docker! Let me start with the basics...

? ❯ I understand images now, what about containers?
AI: Great! Since you understand images, containers are...

? ❯ how do images and containers work together?
AI: Building on what we discussed, images and containers...
```

## 🏆 Power User Tips

### Efficiency Shortcuts
```bash
# Quick mode switching
Ctrl+Space  # Toggle modes instantly

# Quick AI queries without mode switching
ask "quick question"

# Command history with AI context
? ❯ help me understand this command I ran earlier
AI: Looking at your recent commands, that command...
```

### Configuration Optimization
```yaml
# ~/.lacy-shell/config.yaml optimization
detection:
  agent_keywords:
    - "help"
    - "explain" 
    - "debug"
    - "optimize"
    - "tutorial"
    - "best practice"
  
  shell_commands:
    - "git"
    - "npm" 
    - "docker"
    - "kubectl"
    - "terraform"
    # Add your frequently used commands
```

## 🛡️ Troubleshooting Examples

### Common Issues & Solutions
```bash
# Plugin not working
~ ❯ echo $LACY_SHELL_CURRENT_MODE
# Should show current mode

# API not responding  
~ ❯ lacy_shell_test_mcp
# Tests API connectivity

# Mode switching issues
~ ❯ bindkey | grep lacy_shell
# Shows active keybindings
```

## 📈 Metrics & Analytics

### Usage Analysis
```bash
# Understanding your usage patterns
~ ❯ grep "User:" ~/.lacy-shell/conversation.log | wc -l
# Counts your AI queries

~ ❯ analyze my shell usage patterns
AI: Based on conversation history, you frequently use...

~ ❯ tail -50 ~/.lacy-shell/conversation.log
# Reviews recent conversations
```

## 🌟 Community Examples

Share your own examples by contributing to the repository!

### Contributed Workflows

**Scientific Computing** (by @scientist_user):
```bash
~ ❯ help me set up a Python scientific environment
AI: For scientific computing in Python, I recommend...

~ ❯ conda create -n science python=3.9 numpy pandas matplotlib
# Creates conda environment

~ ❯ how do I visualize time series data?
AI: For time series visualization, consider these approaches...
```

**Machine Learning Pipeline** (by @ml_engineer):
```bash
~ ❯ create an ML pipeline for text classification
AI: Here's a complete text classification pipeline...

~ ❯ python preprocess_data.py
# Runs preprocessing

~ ❯ the accuracy is low, what features should I add?
AI: For text classification, consider adding these features...
```

**DevOps Automation** (by @devops_pro):
```bash
~ ❯ help me automate deployment with GitHub Actions
AI: Here's a GitHub Actions workflow for automated deployment...

~ ❯ kubectl get pods
# Checks deployment status

~ ❯ how do I set up monitoring for this deployment?
AI: For Kubernetes monitoring, consider these tools...
```

---

*Contribute your own examples and workflows to help the community! Send a PR with your favorite Lacy Shell use cases.*
