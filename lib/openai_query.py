#!/usr/bin/env python3

import json
import sys
import os
import subprocess
import time

def create_openai_payload(content_file, mcp_tools_file):
    """Create OpenAI API payload with MCP tools"""
    
    # Read content from file
    content = ''
    if os.path.exists(content_file):
        with open(content_file, 'r') as f:
            content = f.read()
    
    # Read MCP tools from file
    mcp_tools = []
    if os.path.exists(mcp_tools_file):
        try:
            with open(mcp_tools_file, 'r') as f:
                mcp_tools = json.load(f)
        except:
            pass
    
    # Convert MCP tools to OpenAI tools format
    tools = []
    for tool in mcp_tools:
        tools.append({
            'type': 'function',
            'function': {
                'name': tool['name'],
                'description': tool['description'],
                'parameters': {
                    'type': 'object',
                    'properties': {
                        'args': {
                            'type': 'object',
                            'description': 'Arguments for the tool'
                        }
                    },
                    'required': ['args']
                }
            }
        })
    
    payload = {
        'model': 'gpt-4',
        'messages': [
            {
                'role': 'system',
                'content': 'You are a helpful AI assistant. For general knowledge questions and simple queries, provide direct, helpful answers. Only use MCP tools when specifically needed for file operations, system commands, or web searches. For most questions, give informative responses without calling tools. Be conversational and helpful.'
            },
            {
                'role': 'user', 
                'content': content
            }
        ],
        'max_tokens': 1500,
        'temperature': 0.3
    }
    
    # Add tools if available
    if tools:
        payload['tools'] = tools
        payload['tool_choice'] = 'auto'
    
    return payload

def process_openai_response(response_data):
    """Process OpenAI API response and handle tool calls"""
    
    try:
        if 'choices' in response_data and len(response_data['choices']) > 0:
            choice = response_data['choices'][0]
            message = choice['message']
            
            # Check if there are tool calls
            if 'tool_calls' in message and message['tool_calls']:
                tool_call = message['tool_calls'][0]  # Take the first tool call
                func_name = tool_call['function']['name']
                func_args = tool_call['function']['arguments']
                
                print(f'🔧 Calling tool: {func_name}', flush=True)
                
                # Determine server name
                server_name = 'filesystem'  # Default
                if 'web' in func_name:
                    server_name = 'web'
                elif 'command' in func_name or 'system' in func_name:
                    server_name = 'system'
                
                # Call actual MCP tool
                try:
                    # Since MCP tools aren't fully implemented yet, provide a helpful response
                    print(f'📋 Tool call requested: {func_name} with args: {func_args}')
                    
                    # Generate a helpful response based on the tool request
                    if 'search' in func_name:
                        return f"I understand you want me to search for information about '{func_args}'. While I can't perform web searches directly right now, I can help you with general knowledge questions. What would you like to know?"
                    elif 'read' in func_name or 'list' in func_name:
                        return f"I can see you want me to access files or directories. I can help you with general questions and provide guidance on file operations, even if I can't directly access your filesystem."
                    else:
                        return f"I received a request for the {func_name} tool. I'm here to help with your questions and provide guidance, even if I can't execute certain system operations directly."
                        
                except Exception as e:
                    print(f'📋 Error calling tool: {e}')
                    return f'Error calling {func_name}: {e}'
                
            elif 'content' in message and message['content']:
                content = message['content']
                # Stream output with typewriter effect
                for char in content:
                    print(char, end='', flush=True)
                    time.sleep(0.008)
                print()  # Final newline
                return content
            else:
                print('No response content available')
                return 'No response content'
        else:
            error_msg = response_data.get('error', {}).get('message', 'API error')
            print(f'Error: {error_msg}')
            return f'Error: {error_msg}'
            
    except Exception as e:
        print(f'Error processing response: {e}')
        return f'Error: {e}'

def main():
    if len(sys.argv) != 4:
        print("Usage: openai_query.py <content_file> <mcp_tools_file> <api_key>")
        sys.exit(1)
    
    content_file = sys.argv[1]
    mcp_tools_file = sys.argv[2]
    api_key = sys.argv[3]
    
    # Create payload
    payload = create_openai_payload(content_file, mcp_tools_file)
    
    # Make API request
    try:
        import subprocess
        result = subprocess.run([
            'curl', '-s',
            '-H', 'Content-Type: application/json',
            '-H', f'Authorization: Bearer {api_key}',
            '-d', json.dumps(payload),
            'https://api.openai.com/v1/chat/completions'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            response_data = json.loads(result.stdout)
            result_content = process_openai_response(response_data)
            return result_content
        else:
            print(f'API request failed: {result.stderr}')
            return 'API request failed'
            
    except Exception as e:
        print(f'Error making API request: {e}')
        return f'Error: {e}'

if __name__ == '__main__':
    main()
