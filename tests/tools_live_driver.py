#!/usr/bin/env python3
"""One live query through Lacy in a real interactive shell.

Used by tests/test_tools_live.sh. Starts the shell in a pty, runs
`tool set <tool>`, asks for PONG, then checks the shell still answers.
Prints one line: STATUS|reason|seconds (STATUS is PASS, AUTH, or FAIL).
The cleaned transcript goes to the path given with --out.
"""
import argparse, fcntl, os, pty, re, select, signal, struct, sys, termios, time

QUERY = "@ reply with only the word pong in capital letters"
AUTH_RE = re.compile(
    r"not logged in|log ?in|sign ?in|unauthori[sz]ed|authenticat|api[ _-]?key|"
    r"credential|\b401\b|\b403\b|invalid.{0,20}token|token.{0,20}expired|"
    # OpenCode Zen's free models refuse lash/opencode `run` and `serve`: the
    # tool has no provider it can use outside the OpenCode app
    r"free tier can only be used from within",
    re.I,
)

ap = argparse.ArgumentParser()
ap.add_argument("--tool", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--prompts", required=True)
ap.add_argument("--timeout", type=float, default=150)
ap.add_argument("cmd", nargs=argparse.REMAINDER)
args = ap.parse_args()
if args.cmd and args.cmd[0] == "--":
    args.cmd = args.cmd[1:]

pid, fd = pty.fork()
if pid == 0:
    os.execvp(args.cmd[0], args.cmd)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 200, 0, 0))

buf = bytearray()

def pump(seconds):
    end = time.time() + seconds
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if not data:
                return False
            buf.extend(data)
    return True


def wait_for(needle, seconds, start=0):
    end = time.time() + seconds
    while time.time() < end:
        if needle in buf[start:]:
            return True
        if not pump(0.1):
            return needle in buf[start:]
    return False


def prompts():
    try:
        return os.path.getsize(args.prompts)
    except OSError:
        return 0


def wait_prompt(n, seconds):
    """Wait until at least n prompts have been drawn."""
    end = time.time() + seconds
    while time.time() < end:
        if prompts() >= n:
            return True
        if not pump(0.1):
            return prompts() >= n
    return False


def clean(b):
    t = b.decode("utf-8", "replace")
    t = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07|\x1b[78]", "", t)
    return t.replace("\r\n", "\n").replace("\r", "\n")


def finish(status, reason, started):
    try:
        os.write(fd, b"exit\r")
        pump(3)
    except OSError:
        pass
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass
    try:
        os.waitpid(pid, 0)
    except OSError:
        pass
    open(args.out, "w").write(clean(bytes(buf)))
    print(f"{status}|{reason}|{int(time.time() - started)}")
    sys.exit(0)


started = time.time()
if not wait_prompt(1, 20):
    finish("FAIL", "shell did not start", started)

# A prompt hook after Lacy's appends a byte per prompt: a new byte means
# the previous line (and any query it started) is finished.
mark = len(buf)
n = prompts()
os.write(fd, f"tool set {args.tool}\r".encode())
wait_prompt(n + 1, 15)
if f"Tool set to: {args.tool}" not in clean(bytes(buf[mark:])):
    tail = [l for l in clean(bytes(buf[mark:])).splitlines() if l.strip()]
    finish("FAIL", "tool set: " + (tail[-1].strip() if tail else "no output"), started)

# Ask. The tool reads the terminal, so nothing is typed until it is done.
pump(0.3)
mark = len(buf)
n = prompts()
q_started = time.time()
os.write(fd, (QUERY + "\r").encode())
done = wait_prompt(n + 1, args.timeout)
got_pong = "PONG" in clean(bytes(buf[mark:]))

# The shell must still answer: nothing frozen, nothing waiting on input
probe = len(buf)
os.write(fd, b"echo __SMOKE_$((40+2))__\r")
responsive = done and wait_for(b"__SMOKE_42__", 20, probe)

reply = clean(bytes(buf[mark:probe]))
if got_pong and responsive:
    finish("PASS", "", started)
if got_pong:
    finish("FAIL", "answered, but the prompt never came back", started)
if AUTH_RE.search(reply):
    finish("AUTH", "not signed in", started)
if not done:
    finish("FAIL", f"no answer in {int(args.timeout)}s", started)
finish("FAIL", "reply had no PONG", started)
