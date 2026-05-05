#!/usr/bin/env bash
# LAC-423: Coordinated Twitter launch thread
# Schedule: May 6, 2026 at 11am ET (15:00 UTC)
# Account: @lacybuilds via xurl
# Prerequisite: Show HN posted at 9am ET (LAC-37)

set -euo pipefail

XURL="xurl --app agents -u lacybuilds --auth oauth2"
GIF_URL="https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-full.gif"
GIF_PATH="/tmp/lacy-demo-full.gif"

echo "=== LAC-423: Posting Twitter launch thread ==="

# Pre-flight: verify xurl auth
echo "Checking @lacybuilds auth..."
AUTH_CHECK=$($XURL whoami 2>&1)
if echo "$AUTH_CHECK" | grep -q "Unauthorized"; then
  echo "FATAL: @lacybuilds OAuth2 token expired."
  echo "Fix: run 'xurl auth oauth2 --app agents' and complete browser flow for lacybuilds."
  exit 1
fi
echo "Auth OK: $(echo "$AUTH_CHECK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('username','unknown'))" 2>/dev/null || echo 'verified')"

# Step 1: Find the Show HN link
echo "Searching for Show HN post..."
HN_LINK=""
# Search HN for the post (posted ~2 hours earlier)
HN_SEARCH=$(curl -s "https://hn.algolia.com/api/v1/search_by_date?query=Lacy+Shell&tags=show_hn&hitsPerPage=5" 2>/dev/null || true)
if [ -n "$HN_SEARCH" ]; then
  HN_ID=$(echo "$HN_SEARCH" | python3 -c "import sys,json; hits=json.load(sys.stdin).get('hits',[]); print(hits[0]['objectID'] if hits else '')" 2>/dev/null || true)
  if [ -n "$HN_ID" ]; then
    HN_LINK="https://news.ycombinator.com/item?id=${HN_ID}"
    echo "Found HN link: $HN_LINK"
  fi
fi

if [ -z "$HN_LINK" ]; then
  echo "WARNING: Could not find Show HN link. Posting without it."
  HN_LINK=""
fi

# Step 2: Download and upload demo GIF
echo "Downloading demo GIF..."
curl -fsSL "$GIF_URL" -o "$GIF_PATH"

echo "Uploading media..."
MEDIA_RESULT=$($XURL media upload "$GIF_PATH" 2>&1)
MEDIA_ID=$(echo "$MEDIA_RESULT" | grep -oE '[0-9]{15,}' | head -1)

if [ -z "$MEDIA_ID" ]; then
  echo "WARNING: Media upload failed. Posting without GIF."
  echo "Upload output: $MEDIA_RESULT"
fi

# Step 3: Post Tweet 1 (Hook) with GIF
echo "Posting Tweet 1 (Hook)..."
TWEET1_TEXT='I made my terminal understand English.

Type a command → it runs in your shell.
Type a question → it goes to your AI agent.

No prefix. No hotkey. Just type.

It'"'"'s called Lacy Shell. Free and open source.'

if [ -n "$MEDIA_ID" ]; then
  TWEET1_RESULT=$($XURL post "$TWEET1_TEXT" --media-id "$MEDIA_ID" 2>&1)
else
  TWEET1_RESULT=$($XURL post "$TWEET1_TEXT" 2>&1)
fi
TWEET1_ID=$(echo "$TWEET1_RESULT" | grep -oE '[0-9]{15,}' | head -1)
echo "Tweet 1 posted: $TWEET1_ID"
sleep 3

# Step 4: Post Tweet 2 (Problem) as reply
echo "Posting Tweet 2 (Problem)..."
TWEET2_TEXT='The problem: every time you need AI help, you leave your terminal.

Copy output. Switch to Claude/ChatGPT. Paste. Wait. Copy answer. Switch back. Paste.

I was doing that 20+ times a day. So I fixed it.'

TWEET2_RESULT=$($XURL reply "$TWEET1_ID" "$TWEET2_TEXT" 2>&1)
TWEET2_ID=$(echo "$TWEET2_RESULT" | grep -oE '[0-9]{15,}' | head -1)
echo "Tweet 2 posted: $TWEET2_ID"
sleep 3

# Step 5: Post Tweet 3 (How it works) as reply
echo "Posting Tweet 3 (How it works)..."
TWEET3_TEXT='How it works:

A color indicator next to your prompt changes as you type:

🟢 Green = runs in your shell
🟣 Magenta = goes to AI

No AI call to classify your input. Pure lexical analysis. Sub-millisecond.

Command fails with NL patterns? Silently reroutes to AI.'

TWEET3_RESULT=$($XURL reply "$TWEET2_ID" "$TWEET3_TEXT" 2>&1)
TWEET3_ID=$(echo "$TWEET3_RESULT" | grep -oE '[0-9]{15,}' | head -1)
echo "Tweet 3 posted: $TWEET3_ID"
sleep 3

# Step 6: Post Tweet 4 (Tool agnostic) as reply
echo "Posting Tweet 4 (Tool agnostic)..."
TWEET4_TEXT='Lacy works with whatever AI tool you already use.

- Claude Code
- Gemini CLI
- OpenCode
- Codex CLI
- Lash
- Any custom command

Auto-detects what'"'"'s installed. Zero config.'

TWEET4_RESULT=$($XURL reply "$TWEET3_ID" "$TWEET4_TEXT" 2>&1)
TWEET4_ID=$(echo "$TWEET4_RESULT" | grep -oE '[0-9]{15,}' | head -1)
echo "Tweet 4 posted: $TWEET4_ID"
sleep 3

# Step 7: Post Tweet 5 (CTA) as reply
echo "Posting Tweet 5 (CTA)..."
TWEET5_TEXT="One line to install:

curl -fsSL https://lacy.sh/install | bash

Or: brew install lacymorrow/tap/lacy

ZSH + Bash 4+. macOS, Linux, WSL.

github.com/lacymorrow/lacy"

# Append HN link if found
if [ -n "$HN_LINK" ]; then
  TWEET5_TEXT="${TWEET5_TEXT}

Live on HN: ${HN_LINK}"
fi

TWEET5_TEXT="${TWEET5_TEXT}

cc @AnthropicAI @GoogleDeepMind"

TWEET5_RESULT=$($XURL reply "$TWEET4_ID" "$TWEET5_TEXT" 2>&1)
TWEET5_ID=$(echo "$TWEET5_RESULT" | grep -oE '[0-9]{15,}' | head -1)
echo "Tweet 5 posted: $TWEET5_ID"

# Done
echo ""
echo "=== Thread posted successfully ==="
echo "Thread URL: https://x.com/lacybuilds/status/$TWEET1_ID"

# Cleanup
rm -f "$GIF_PATH"
