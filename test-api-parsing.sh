#!/usr/bin/env zsh

echo "🧪 Testing API Response Parsing"
echo "==============================="
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Test OpenAI response parsing
echo "1. Testing OpenAI response parsing:"
echo "-----------------------------------"

# Create a mock OpenAI response
openai_response='{
  "id": "chatcmpl-C4iL0Matmq1qnMwKPDAfwgzv27lN8",
  "object": "chat.completion",
  "created": 1735000000,
  "model": "gpt-4",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! How can I help you today?"
      },
      "finish_reason": "stop"
    }
  ]
}'

echo "Mock OpenAI response created"
echo ""

# Test Python parsing
if command -v python3 >/dev/null 2>&1; then
    echo "Testing Python parsing:"
    content=$(echo "$openai_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'choices' in data and len(data['choices']) > 0:
        content = data['choices'][0]['message']['content']
        print(content)
except Exception as e:
    print('Error:', e, file=sys.stderr)
" 2>&1)
    
    if [[ -n "$content" ]]; then
        echo "  ✅ Parsed content: $content"
    else
        echo "  ❌ Failed to parse content"
    fi
else
    echo "Python not available, skipping Python test"
fi

echo ""

# Test sed parsing
echo "Testing sed parsing:"
content=$(echo "$openai_response" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [[ -n "$content" ]]; then
    echo "  ✅ Parsed content: $content"
else
    echo "  ❌ Failed to parse content"
fi

echo ""
echo "2. Testing Anthropic response parsing:"
echo "--------------------------------------"

# Create a mock Anthropic response
anthropic_response='{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Hello! I can help you with that."
    }
  ]
}'

echo "Mock Anthropic response created"
echo ""

# Test Python parsing
if command -v python3 >/dev/null 2>&1; then
    echo "Testing Python parsing:"
    content=$(echo "$anthropic_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'content' in data and len(data['content']) > 0:
        for block in data['content']:
            if block.get('type') == 'text':
                print(block.get('text', ''))
except Exception as e:
    print('Error:', e, file=sys.stderr)
" 2>&1)
    
    if [[ -n "$content" ]]; then
        echo "  ✅ Parsed content: $content"
    else
        echo "  ❌ Failed to parse content"
    fi
else
    echo "Python not available, skipping Python test"
fi

echo ""

# Test sed parsing  
echo "Testing sed parsing:"
content=$(echo "$anthropic_response" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [[ -n "$content" ]]; then
    echo "  ✅ Parsed content: $content"
else
    echo "  ❌ Failed to parse content"
fi

echo ""
echo "3. Testing actual API functions:"
echo "--------------------------------"

# Create test input
cat > /tmp/test-api-input.txt << EOF
System Context:
- Current Directory: $(pwd)
- Current Date: $(date)
- Shell: $SHELL
- User: $USER

Current Query: test query
EOF

# Test if functions exist
if declare -f lacy_shell_query_openai_streaming > /dev/null; then
    echo "  ✅ OpenAI streaming function exists"
else
    echo "  ❌ OpenAI streaming function not found"
fi

if declare -f lacy_shell_query_anthropic_streaming > /dev/null; then
    echo "  ✅ Anthropic streaming function exists"
else
    echo "  ❌ Anthropic streaming function not found"
fi

# Clean up
rm -f /tmp/test-api-input.txt

echo ""
echo "Testing complete!"