"""Stream a `claude -p --output-format stream-json` answer to the terminal.

Reads claude's NDJSON events on stdin and prints answer text the moment each
chunk arrives. Stops the spinner (argv[1], a PID or empty) at the first chunk.
Writes the final `result` event to argv[2] so the caller can read the session
ID and errors; when claude printed no result event, the non-JSON output
(startup noise, error text) is written there instead. Creates argv[2] +
".printed" when any answer text reached the terminal.

Ctrl+C reaches this process too, since SIGINT goes to the whole foreground
group. It stops where it is, keeps the text already on screen, and exits 130
without a traceback.

Also writes every shell command claude ran to argv[2] + ".commands", one
`ok<TAB>command` / `err<TAB>command` line each, in the order they ran, so the
caller can show what touched the machine. Commands come from the stream's
`tool_use` blocks, never from parsing claude's prose, and are flattened to a
single line each. Written at the end alongside the result; on an interrupted
turn the caller returns on the signal exit code and lists nothing.
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
commands = []   # [id, command, failed] per Bash tool call, in stream order
by_id = {}


def stop_spinner():
    if spinner:
        try:
            os.kill(spinner, signal.SIGTERM)
        except OSError:
            pass
        time.sleep(0.05)  # let a frame in flight land before clearing it
    sys.stderr.write("\x1b[2K\r\x1b[?25h")
    sys.stderr.flush()


def flatten(command):
    """One command, one line: collapse newlines and runs of blank space so a
    heredoc or a wrapped pipeline cannot break the list apart."""
    return " ".join(str(command).split())


def record_tool_use(event):
    """Collect the shell commands from an assistant message. The assistant
    event carries each tool_use block's full input, so the partial
    input_json_delta fragments never have to be reassembled."""
    for block in event.get("message", {}).get("content", []) or []:
        if block.get("type") != "tool_use" or block.get("name") != "Bash":
            continue
        command = flatten(block.get("input", {}).get("command", ""))
        if not command:
            continue
        entry = [block.get("id"), command, False]
        commands.append(entry)
        if entry[0] is not None:
            by_id[entry[0]] = entry


def record_tool_result(event):
    """Mark the commands that failed, matched back by tool_use_id."""
    for block in event.get("message", {}).get("content", []) or []:
        if block.get("type") != "tool_result":
            continue
        entry = by_id.get(block.get("tool_use_id"))
        if entry is not None and block.get("is_error"):
            entry[2] = True


def write(text):
    global printed, at_line_start
    if not printed:
        stop_spinner()
        printed = True
    sys.stdout.write(text)
    sys.stdout.flush()
    at_line_start = text.endswith("\n")


interrupted = False

try:
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
        elif kind == "assistant":
            record_tool_use(event)
        elif kind == "user":
            record_tool_result(event)
        elif kind == "result":
            result = line
except KeyboardInterrupt:
    interrupted = True

try:
    if printed and not at_line_start:
        sys.stdout.write("\n")
        sys.stdout.flush()
    with open(result_path, "w") as f:
        f.write(result if result is not None else "".join(other))
    if commands:
        with open(result_path + ".commands", "w") as f:
            for _id, command, failed in commands:
                f.write("%s\t%s\n" % ("err" if failed else "ok", command))
    if printed:
        # Tells the caller not to print the answer a second time
        open(result_path + ".printed", "w").close()
except KeyboardInterrupt:
    # A second Ctrl+C while finishing up: still no traceback
    interrupted = True

if interrupted:
    sys.exit(130)
