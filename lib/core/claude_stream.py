"""Stream a `claude -p --output-format stream-json` answer to the terminal.

Reads claude's NDJSON events on stdin and prints answer text the moment each
chunk arrives. Stops the spinner (argv[1], a PID or empty) at the first chunk.
Writes the final `result` event to argv[2] so the caller can read the session
ID and errors; when claude printed no result event, the non-JSON output
(startup noise, error text) is written there instead. Creates argv[2] +
".printed" when any answer text reached the terminal.
"""
import json
import os
import signal
import sys
import time

spinner = int(sys.argv[1]) if sys.argv[1].isdigit() else 0
result_path = sys.argv[2]

printed = False
at_line_start = True
result = None
other = []


def stop_spinner():
    if spinner:
        try:
            os.kill(spinner, signal.SIGTERM)
        except OSError:
            pass
        time.sleep(0.05)  # let a frame in flight land before clearing it
    sys.stderr.write("\x1b[2K\r\x1b[?25h")
    sys.stderr.flush()


def write(text):
    global printed, at_line_start
    if not printed:
        stop_spinner()
        printed = True
    sys.stdout.write(text)
    sys.stdout.flush()
    at_line_start = text.endswith("\n")


for line in sys.stdin:
    try:
        event = json.loads(line)
    except ValueError:
        other.append(line)
        continue
    kind = event.get("type")
    if kind == "stream_event":
        inner = event.get("event", {})
        # A new assistant message after a tool call: keep it off the last line
        if inner.get("type") == "message_start" and printed:
            write("\n" if at_line_start else "\n\n")
        delta = inner.get("delta", {})
        if delta.get("type") == "text_delta" and delta.get("text"):
            write(delta["text"])
    elif kind == "result":
        result = line

if printed and not at_line_start:
    sys.stdout.write("\n")
with open(result_path, "w") as f:
    f.write(result if result is not None else "".join(other))
if printed:
    # Tells the caller not to print the answer a second time
    open(result_path + ".printed", "w").close()
