#!/usr/bin/env zsh

echo "🔍 Debugging API Call"
echo "===================="
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Check API keys
echo "1. API Keys:"
if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
    echo "   OpenAI: Configured (${#LACY_SHELL_API_OPENAI} chars)"
else
    echo "   OpenAI: Not configured"
fi

if [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
    echo "   Anthropic: Configured (${#LACY_SHELL_API_ANTHROPIC} chars)"
else
    echo "   Anthropic: Not configured"
fi
echo ""

# Test the actual API call
echo "2. Testing actual API call:"
echo "   Creating test query..."

# Create test input
cat > /tmp/test-api.txt << EOF
System Context:
- Current Directory: $(pwd)
- Current Date: $(date)
- Shell: $SHELL
- User: $USER

Current Query: hi
EOF

echo "   Input file created"
echo ""

# Try OpenAI if configured
if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
    echo "3. Testing OpenAI API directly:"
    
    # Create a simple JSON payload
    content=$(cat /tmp/test-api.txt | tr '\n' ' ' | sed 's/"/\\"/g')
    json_payload="{
  \"model\": \"gpt-4\",
  \"messages\": [
    {
      \"role\": \"system\",
      \"content\": \"You are a helpful assistant. Provide concise, practical responses.\"
    },
    {
      \"role\": \"user\",
      \"content\": \"$content\"
    }
  ],
  \"temperature\": 0.3,
  \"max_tokens\": 1500
}"
    
    echo "   Sending request to OpenAI..."
    response=$(curl -s -w "\n\nHTTP_CODE:%{http_code}" \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $LACY_SHELL_API_OPENAI" \
         -d "$json_payload" \
         "https://api.openai.com/v1/chat/completions")
    
    # Extract HTTP code
    http_code=$(echo "$response" | grep "HTTP_CODE:" | sed 's/.*HTTP_CODE://')
    api_response=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    echo "   HTTP Response Code: $http_code"
    
    if [[ "$http_code" == "200" ]]; then
        echo "   ✅ API call successful!"
        echo "   Response preview:"
        echo "$api_response" | head -3
    else
        echo "   ❌ API call failed!"
        echo "   Error response:"
        echo "$api_response" | head -10
    fi
fi

# Try Anthropic if configured and OpenAI isn't
if [[ -z "$LACY_SHELL_API_OPENAI" ]] && [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
    echo "3. Testing Anthropic API directly:"
    
    # Create a simple JSON payload
    content=$(cat /tmp/test-api.txt | tr '\n' ' ' | sed 's/"/\\"/g')
    json_payload="{
  \"model\": \"claude-3-5-sonnet-20241022\",
  \"max_tokens\": 1500,
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": \"$content\"
    }
  ]
}"
    
    echo "   Sending request to Anthropic..."
    response=$(curl -s -w "\n\nHTTP_CODE:%{http_code}" \
         -H "Content-Type: application/json" \
         -H "x-api-key: $LACY_SHELL_API_ANTHROPIC" \
         -H "anthropic-version: 2023-06-01" \
         -d "$json_payload" \
         "https://api.anthropic.com/v1/messages")
    
    # Extract HTTP code
    http_code=$(echo "$response" | grep "HTTP_CODE:" | sed 's/.*HTTP_CODE://')
    api_response=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    echo "   HTTP Response Code: $http_code"
    
    if [[ "$http_code" == "200" ]]; then
        echo "   ✅ API call successful!"
        echo "   Response preview:"
        echo "$api_response" | head -3
    else
        echo "   ❌ API call failed!"
        echo "   Error response:"
        echo "$api_response" | head -10
    fi
fi

echo ""
echo "4. Testing the plugin's query function:"
type lacy_shell_query_openai_streaming | head -5

# Clean up
rm -f /tmp/test-api.txt