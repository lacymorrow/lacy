#!/usr/bin/env zsh

echo "Debugging JSON payload creation"
echo "================================"
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Create test input
cat > /tmp/test-json-input.txt << 'EOF'
System Context:
- Current Directory: /Users/test
- Current Date: 2024-01-01
- Shell: /bin/zsh
- User: test

Current Query: can you ping google.com
EOF

echo "Input file content:"
cat /tmp/test-json-input.txt
echo ""
echo "---"
echo ""

# Test Python JSON creation
if command -v python3 >/dev/null 2>&1; then
    echo "Testing Python JSON creation:"
    content=$(cat /tmp/test-json-input.txt)
    
    python3 -c "
import json

content = '''$content'''

payload = {
    'model': 'gpt-4',
    'messages': [
        {
            'role': 'system',
            'content': 'You are a helpful assistant. Provide concise, practical responses.'
        },
        {
            'role': 'user',
            'content': content
        }
    ],
    'temperature': 0.3,
    'max_tokens': 1500
}

print('JSON is valid:', json.dumps(payload) is not None)
print('Content preview:', content[:50])
" 2>&1
fi

# Clean up
rm -f /tmp/test-json-input.txt