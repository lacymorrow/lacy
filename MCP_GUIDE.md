# MCP Integration Guide

This guide explains how to use Lacy Shell's Model Context Protocol (MCP) integration for enhanced AI capabilities.

## 🚀 Quick Start

### 1. Install MCP Servers

```bash
# Install the filesystem server (required)
npm install -g @modelcontextprotocol/server-filesystem

# Install optional servers
npm install -g @modelcontextprotocol/server-web
```

### 2. Configure Servers

Edit `~/.lacy-shell/config.yaml`:

```yaml
mcp:
  servers:
    - name: "filesystem"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/Users/yourname"]
    - name: "web"
      command: "npx"
      args: ["@modelcontextprotocol/server-web"]
```

### 3. Test Configuration

```bash
# Test MCP setup
mcp_test

# Start servers manually (they auto-start with the plugin)
mcp_start

# Check server status
mcp_debug filesystem
```

## 🔧 Available Commands

### Management Commands

| Command | Description |
|---------|-------------|
| `mcp_test` | Test MCP configuration and server status |
| `mcp_start` | Start all configured MCP servers |
| `mcp_stop` | Stop all MCP servers |
| `mcp_restart <server>` | Restart a specific server |
| `mcp_debug <server>` | Show debug info for a server |
| `mcp_logs <server>` | View server logs |

### AI Integration

The AI can automatically use MCP tools when you ask appropriate questions:

```bash
# Filesystem operations
ask "what files are in this directory?"
ask "read the contents of README.md"
ask "create a new file called test.txt with hello world"

# Web searches (if web server configured)
ask "search for the latest Node.js version"
ask "what's the weather in San Francisco?"

# System information
ask "what's my current memory usage?"
ask "show me running processes"
```

## 📁 Server Types

### Filesystem Server

**Purpose:** File and directory operations

**Configuration:**
```yaml
- name: "filesystem"
  command: "npx"
  args: ["@modelcontextprotocol/server-filesystem", "/allowed/path"]
```

**Available Tools:**
- `read_file` - Read file contents
- `write_file` - Write to files
- `list_directory` - List directory contents
- `create_directory` - Create directories
- `delete_file` - Delete files
- `move_file` - Move/rename files

**Security:** Only allows operations within the specified path.

### Web Server

**Purpose:** Web searches and content retrieval

**Configuration:**
```yaml
- name: "web"
  command: "npx"
  args: ["@modelcontextprotocol/server-web"]
```

**Available Tools:**
- `search_web` - Search the internet
- `fetch_url` - Retrieve content from URLs
- `extract_content` - Extract text from web pages

### System Server (Future)

**Purpose:** System information and safe command execution

**Planned Tools:**
- `get_system_info` - System metrics
- `list_processes` - Running processes
- `check_disk_space` - Disk usage
- `get_network_info` - Network status

## 🔍 Debugging

### Server Status

```bash
# Check if servers are running
mcp_test

# Debug specific server
mcp_debug filesystem
```

### Common Issues

**Server won't start:**
```bash
# Check if the MCP package is installed
npm list -g @modelcontextprotocol/server-filesystem

# Check logs for errors
mcp_logs filesystem

# Restart server
mcp_restart filesystem
```

**AI not using tools:**
- Ensure API keys are configured
- Check that servers are running (`mcp_test`)
- Verify the AI request matches available tools

**Permission errors:**
- Check that the filesystem server path allows access
- Ensure the user has proper permissions

### Debug Mode

Set debug mode in your config:

```yaml
debug:
  mcp: true
  verbose_logging: true
```

## 🛠️ Advanced Configuration

### Custom Server Paths

```yaml
mcp:
  servers:
    - name: "projects"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/Users/yourname/Projects"]
    - name: "docs"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/Users/yourname/Documents"]
```

### Multiple Instances

You can run multiple instances of the same server type:

```yaml
mcp:
  servers:
    - name: "home_files"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/Users/yourname"]
    - name: "work_files"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/work/projects"]
```

### Server-Specific Settings

```yaml
mcp:
  servers:
    - name: "filesystem"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem"]
      env:
        FILESYSTEM_ROOT: "/safe/path"
        LOG_LEVEL: "debug"
      timeout: 30
      restart_on_failure: true
```

## 📊 Performance Tips

### Optimization

1. **Limit filesystem access:** Only grant access to necessary directories
2. **Monitor server resources:** Use `mcp_debug` to check server health
3. **Restart periodically:** Servers can accumulate memory over time
4. **Use specific queries:** More specific AI requests use tools more efficiently

### Monitoring

```bash
# Check server resource usage
for server in filesystem web; do
    echo "=== $server ==="
    mcp_debug $server | grep -E "(PID|Memory|CPU)"
done
```

## 🔐 Security Considerations

### Filesystem Access

- Always use the minimum required path scope
- Never grant access to system directories (`/`, `/etc`, `/var`)
- Consider using symbolic links to limit access

### Web Access

- Web server can access any public URL
- Consider network policies if running in restricted environments
- Monitor for rate limiting from external services

### API Keys

- MCP servers don't access your API keys
- Keys are only used for AI model communication
- Store keys securely in the config file with proper permissions

## 🤝 Contributing

To add new MCP server types:

1. Install the MCP server package
2. Add configuration to your `config.yaml`
3. Test with `mcp_test`
4. Update this guide with new capabilities

For custom servers, see the [MCP specification](https://modelcontextprotocol.io/).

## 📚 References

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCP Filesystem Server](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem)
- [MCP Web Server](https://github.com/modelcontextprotocol/servers/tree/main/src/web)
- [Lacy Shell Documentation](./README.md)
