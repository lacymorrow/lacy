"""Keep one claude process running per shell so questions skip startup.

  start <sock> <shell_pid> <idle_secs> [session_id]
      Start claude (stream-json in and out) in the current directory, behind
      a unix socket. Returns once the socket is listening; the keeper itself
      runs detached. It exits when the shell is gone, after idle_secs without
      a question, when claude exits, or on SIGTERM. Writes <sock>.pid and
      <sock>.cwd so the shell can find and check it.

  ask <sock>
      Send the question on stdin to the keeper and print claude's NDJSON
      events for that turn (through the `result` event) on stdout, for
      claude_stream.py. Exit 0 on an answer, 1 on an error result or a
      broken turn, 75 when the keeper could not take the question at all
      (nothing was printed; the caller runs claude the usual way).

A closed connection mid-answer (Ctrl+C) interrupts claude's turn; the
conversation and the process stay.
"""
import json
import os
import select
import signal
import socket
import subprocess
import sys
import time

UNAVAILABLE = 75


def at_socket_dir(sock_path, action):
    """Run action(name) from the socket's directory: unix socket paths are
    capped near 104 bytes, and a relative name keeps deep homes working."""
    here = os.getcwd()
    os.chdir(os.path.dirname(sock_path) or ".")
    try:
        return action(os.path.basename(sock_path))
    finally:
        os.chdir(here)


class Lines:
    """Line reader for select loops. Python's buffered readline can pull
    several lines off the pipe at once, and select then never reports the
    ones already buffered; this keeps the buffer visible."""

    def __init__(self, fd):
        self.fd = fd
        self.buf = b""

    def pop(self):
        end = self.buf.find(b"\n")
        if end < 0:
            return None
        line, self.buf = self.buf[:end + 1], self.buf[end + 1:]
        return line

    def fill(self):
        chunk = os.read(self.fd, 65536)
        self.buf += chunk
        return bool(chunk)


def ask(sock_path):
    query = sys.stdin.read()
    try:
        conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        at_socket_dir(sock_path, conn.connect)
        conn.sendall((json.dumps({"q": query, "cwd": os.getcwd()}) + "\n").encode())
    except OSError:
        return UNAVAILABLE
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    reader = conn.makefile("rb")
    got_event = False
    held = []  # non-JSON lines, printed only once the turn has started
    for raw in reader:
        line = raw.decode("utf-8", "replace")
        try:
            event = json.loads(line)
        except ValueError:
            held.append(line)
            continue
        if event.get("type") == "lacy_keeper":
            return UNAVAILABLE
        if not got_event:
            got_event = True
            sys.stdout.write("".join(held))
            held = []
        sys.stdout.write(line)
        sys.stdout.flush()
        if event.get("type") == "result":
            return 1 if event.get("is_error") else 0
    if not got_event:
        return UNAVAILABLE
    # claude went away mid-answer: hand over whatever it said on the way out
    sys.stdout.write("".join(held))
    return 1


def start(sock_path, shell_pid, idle_secs, session_id):
    ready_r, ready_w = os.pipe()
    if os.fork():
        os.close(ready_w)
        # Wait for the keeper to listen, so an ask right after this connects
        select.select([ready_r], [], [], 5)
        return 0 if os.read(ready_r, 1) == b"1" else 1
    os.close(ready_r)
    os.setsid()
    if os.fork():
        os._exit(0)
    try:
        serve(sock_path, shell_pid, idle_secs, session_id, ready_w)
    finally:
        os._exit(0)


def serve(sock_path, shell_pid, idle_secs, session_id, ready_w):
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)

    try:
        os.unlink(sock_path)
    except OSError:
        pass
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    old_umask = os.umask(0o177)
    try:
        at_socket_dir(sock_path, listener.bind)
    finally:
        os.umask(old_umask)
    listener.listen(1)

    env = dict(os.environ)
    env.pop("CLAUDECODE", None)
    argv = ["claude", "-p", "--input-format", "stream-json",
            "--output-format", "stream-json", "--include-partial-messages", "--verbose"]
    if session_id:
        argv += ["--resume", session_id]
    log_path = sock_path + ".log"
    log = open(log_path, "w")
    try:
        claude = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=log, env=env)
    except OSError:
        listener.close()
        os.unlink(sock_path)
        os.write(ready_w, b"0")
        return

    cwd = os.getcwd()
    for suffix, text in ((".pid", str(os.getpid())), (".cwd", cwd)):
        with open(sock_path + suffix, "w") as f:
            f.write(text + "\n")

    def shutdown(*_):
        try:
            claude.terminate()
            claude.wait(timeout=3)
        except Exception:
            claude.kill()
        # A newer keeper may already own these paths; leave its files alone
        try:
            with open(sock_path + ".pid") as f:
                mine = f.read().strip() == str(os.getpid())
        except OSError:
            mine = False
        if mine:
            for path in (sock_path, sock_path + ".pid", sock_path + ".cwd", log_path):
                try:
                    os.unlink(path)
                except OSError:
                    pass
        os._exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    os.write(ready_w, b"1")
    os.close(ready_w)

    lines = Lines(claude.stdout.fileno())
    last_used = time.time()
    while True:
        # Output with nobody asking (a late event): drop it
        while lines.pop() is not None:
            pass
        ready, _, _ = select.select([listener, lines.fd], [], [], 2)
        if lines.fd in ready and listener not in ready:
            if not lines.fill():
                shutdown()
            continue
        if claude.poll() is not None:
            shutdown()
        if listener in ready:
            conn, _ = listener.accept()
            if not turn(conn, claude, lines, cwd, log_path):
                conn.close()
                shutdown()
            conn.close()
            last_used = time.time()
            continue
        try:
            os.kill(shell_pid, 0)
        except OSError:
            shutdown()
        if idle_secs > 0 and time.time() - last_used > idle_secs:
            shutdown()


def turn(conn, claude, lines, cwd, log_path):
    """Run one question. False when the keeper should stop."""
    conn.settimeout(10)
    try:
        request = json.loads(conn.makefile("rb").readline() or b"{}")
    except (ValueError, OSError):
        return True
    conn.settimeout(None)
    if request.get("cwd") != cwd or not request.get("q"):
        # Tools run in claude's directory; a question from elsewhere needs a
        # keeper started there. Refuse it and step aside for that one.
        send(conn, json.dumps({"type": "lacy_keeper", "status": "cwd"}) + "\n")
        return request.get("cwd") == cwd

    message = {"type": "user", "message": {"role": "user", "content": request["q"]}}
    try:
        claude.stdin.write((json.dumps(message) + "\n").encode())
        claude.stdin.flush()
    except OSError:
        return False

    listening = True
    interrupted = False
    while True:
        line = lines.pop()
        if line is None:
            watch = [lines.fd] + ([conn] if listening else [])
            ready, _, _ = select.select(watch, [], [])
            if conn in ready and listening:
                # The asker never sends more; readable means it hung up
                try:
                    gone = not conn.recv(1)
                except OSError:
                    gone = True
                if gone:
                    listening = False
                    interrupted = interrupt(claude)
            if lines.fd in ready and not lines.fill():
                if listening:
                    send(conn, stderr_tail(log_path))
                return False
            continue
        try:
            kind = json.loads(line).get("type")
        except ValueError:
            kind = None
        if kind in ("control_response", "control_request"):
            continue
        if listening and not send(conn, line.decode("utf-8", "replace")):
            listening = False
            interrupted = interrupt(claude)
        if kind == "result":
            return True
        if not listening and not interrupted:
            return False


def interrupt(claude):
    request = {"type": "control_request", "request_id": "lacy-interrupt-%d" % time.time(),
               "request": {"subtype": "interrupt"}}
    try:
        claude.stdin.write((json.dumps(request) + "\n").encode())
        claude.stdin.flush()
        return True
    except OSError:
        return False


def send(conn, text):
    try:
        conn.sendall(text.encode())
        return True
    except OSError:
        return False


def stderr_tail(log_path):
    try:
        with open(log_path) as f:
            lines = f.readlines()[-20:]
    except OSError:
        return ""
    return "".join(lines)


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "ask":
        return ask(sys.argv[2])
    if len(sys.argv) >= 5 and sys.argv[1] == "start":
        session_id = sys.argv[5] if len(sys.argv) > 5 else ""
        return start(sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), session_id)
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
