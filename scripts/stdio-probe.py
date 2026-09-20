#!/usr/bin/env python3
"""stdio-probe: the descriptor states the conformance harness cannot express (it feeds regular files at
offset 0 and reads pipes): an inherited offset, a socket, a file unreadable by path, O_NONBLOCK, closed
and full standard streams. Each row runs the pinned original and the port the same way and compares
stdout, stderr, the exit code and, where it matters, what is LEFT on the shared stdin.

A row is SAME, KNOWN (it differs and names the DISC entry that registers the difference) or NEW (it
differs and nothing registers it: a finding). A row that was KNOWN and is SAME now is reported as FIXED.
usage: python3 scripts/stdio-probe.py [--original PATH] [--timeout S] -- <port command...>
exit: 0 no NEW row, 1 otherwise, 2 usage. Last stdout line: JSON summary. Writes only under a fresh temp dir.
"""
import fcntl, json, os, socket, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    argv = sys.argv[1:]
    if "--" not in argv or "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0 if ("-h" in argv or "--help" in argv) else 2
    cut = argv.index("--")
    head, port = argv[:cut], [os.path.abspath(w) if os.path.exists(w) else w for w in argv[cut + 1:]]  # rows run in a temp cwd
    original, limit = os.path.join(ROOT, "oracle", "toon"), 10.0
    for i in range(0, len(head) - 1, 2):
        if head[i] == "--original":
            original = head[i + 1]
        elif head[i] == "--timeout":
            limit = float(head[i + 1])
    if not (os.path.isfile(original) and os.access(original, os.X_OK)):
        print("stdio-probe: the pinned original is not at %s (it is not part of the repository: docs/PIN.toml names its commit and sha256; pass --original PATH)" % original, file=sys.stderr)
        return 2
    work = tempfile.mkdtemp(prefix="stdio-probe.")
    doc = "skipped: 1\nkept: 2\nalso: 3\n"
    big = os.path.join(work, "big.json")
    with open(big, "w", encoding="utf-8") as fh:
        json.dump(["string number %d" % i for i in range(4000)], fh)
    small = os.path.join(work, "small.json")
    with open(small, "w", encoding="utf-8") as fh:
        fh.write('{"a":1}')

    def run(cmd, args, stdin=None, pre=None, stdout=subprocess.PIPE, stderr=subprocess.PIPE, feed=None, keep_fds=False):
        try:
            p = subprocess.Popen(cmd + args, stdin=stdin, stdout=stdout, stderr=stderr, preexec_fn=pre, cwd=work,
                                 close_fds=not keep_fds)
            if feed:
                feed(p)
            out, err = p.communicate(timeout=limit)
            return (p.returncode, out, err)
        except subprocess.TimeoutExpired:
            p.kill()
            p.communicate()
            return ("HANG", None, None)

    rows = []

    def row(name, known, fn):
        a, b = fn(original_cmd), fn(port)
        same = a == b
        status = "SAME" if same and not known else ("FIXED" if same else ("KNOWN" if known else "NEW"))
        r = {"row": name, "status": status}
        if known:
            r["disc"] = known
        if not same:
            r["original"], r["port"] = repr(a)[:240], repr(b)[:240]
        rows.append(r)
        print(json.dumps(r), flush=True)

    original_cmd = [original]

    def offset(k, args):
        def f(cmd):
            path = os.path.join(work, "offset.toon")
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(doc)
            fd = os.open(path, os.O_RDONLY)
            try:
                os.lseek(fd, k, os.SEEK_SET)
                res = run(cmd, args, stdin=fd)
                return res + (os.lseek(fd, 0, os.SEEK_CUR),)
            finally:
                os.close(fd)
        return f

    def sock(cmd):
        a, b = socket.socketpair()
        with a, b:
            b.sendall(b"[1,2]")
            b.shutdown(socket.SHUT_WR)
            return run(cmd, ["-e"], stdin=a.fileno())

    def unreadable(cmd):
        path = os.path.join(work, "perm.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write('{"perm":1}')
        fd = os.open(path, os.O_RDONLY)
        try:
            os.chmod(path, 0)
            return run(cmd, ["-e"], stdin=fd)
        finally:
            os.chmod(path, 0o644)
            os.close(fd)

    def nonblocking(cmd):
        rd, wr = os.pipe()
        fcntl.fcntl(rd, fcntl.F_SETFL, fcntl.fcntl(rd, fcntl.F_GETFL) | os.O_NONBLOCK)
        res = run(cmd, ["-e"], stdin=rd)
        os.close(rd)
        os.close(wr)
        return res

    def closed(fds, args):
        def f(cmd):
            def pre():
                for fd in fds:
                    os.close(fd)
            return run(cmd, args, stdin=subprocess.DEVNULL if 0 not in fds else None, pre=pre,
                       stdout=None if 1 in fds else subprocess.PIPE, stderr=None if 2 in fds else subprocess.PIPE)
        return f

    def full(which, args, data):
        def f(cmd):
            dev = os.open("/dev/full", os.O_WRONLY)
            rd, wr = os.pipe()
            try:
                os.write(wr, data)
                os.close(wr)
                return run(cmd, args, stdin=rd, **({"stdout": dev} if which == 1 else {"stderr": dev}))
            finally:
                os.close(rd)
                os.close(dev)
        return f

    def wrong_mode(which, args, data=b"[1,2]"):
        def f(cmd):
            path = os.path.join(work, "mode%d" % which)
            with open(path, "wb") as fh:
                fh.write(data if which == 0 else b"")
            fd = os.open(path, os.O_WRONLY if which == 0 else os.O_RDONLY)
            rd, wr = os.pipe()
            try:
                os.write(wr, data)
                os.close(wr)
                kw = {"stdin": fd} if which == 0 else ({"stdin": rd, "stdout": fd} if which == 1 else {"stdin": rd, "stderr": fd})
                return run(cmd, args, **kw)
            finally:
                os.close(rd)
                os.close(fd)
        return f

    row("stdin is open WRITE-only, decode (the original reads an empty input)", "", wrong_mode(0, ["-d"]))
    row("stdin is open WRITE-only, encode", "", wrong_mode(0, ["-e"]))
    row("stdout is open READ-only", "DISC-006", wrong_mode(1, ["-e"]))
    row("stderr is open READ-only, a success line to write", "DISC-003", wrong_mode(2, ["-e", "-o", os.path.join(work, "out2.toon")]))
    def seqpacket(payload, args=("-e",)):
        """One SEQPACKET message: a read shorter than the message discards its rest, so the original (which
        asks for 32 bytes first) and the port (one read of 1 MiB) see DIFFERENT bytes. DISC-015."""
        def f(cmd):
            a, b = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
            with a, b:
                b.sendall(payload)
                b.shutdown(socket.SHUT_WR)
                return run(cmd, list(args), stdin=a.fileno())
        return f

    def arr(n):
        return ("[" + ",".join("1" for _ in range(n)) + "]").encode()

    row("stdin is a SEQPACKET socket, one message of 31 bytes", "", seqpacket(arr(15)))
    row("stdin is a SEQPACKET socket, one message of 41 bytes: the original sees a cut-off document", "DISC-015", seqpacket(arr(20)))
    row("stdin is a SEQPACKET socket, one message of 45 bytes: the original sees a COMPLETE document and stops", "DISC-015", seqpacket(arr(15) + b"\n" + b" " * 13 + b"x"))
    row("stdin is a SEQPACKET socket, one message of 44 TOON bytes: both exit 0 and the bytes differ", "DISC-015",
        seqpacket(b"aaaaaaa: 1\nbbbbbbb: 2\nccccccc: 3\nddddddd: 4\n", ("-d",)))
    row("INPUT is /dev/fd/9, which nobody opened", "", lambda cmd: run(cmd, ["-d", "/dev/fd/9"], stdin=subprocess.DEVNULL))

    def caller_fd9(cmd):
        """INPUT /dev/fd/9 WITH descriptor 9 supplied by the caller: a launcher that probes the standard
        descriptors must not spend descriptor 9 doing it (round 12 found `bin/toon` did)."""
        fd = os.open(small, os.O_RDONLY)
        try:
            return run(cmd, ["-e", "/dev/fd/9"], stdin=subprocess.DEVNULL, keep_fds=True,
                       pre=lambda: os.dup2(fd, 9))
        finally:
            os.close(fd)

    row("INPUT is /dev/fd/9 and the caller DID open descriptor 9", "", caller_fd9)
    row("-o /dev/fd/3, which the caller did not open", "DISC-014", lambda cmd: run(cmd, ["-e", small, "-o", "/dev/fd/3"], stdin=subprocess.DEVNULL))
    row("stdin is a regular file at offset 11", "", offset(11, ["-d"]))
    row("stdin is a regular file at its end", "", offset(len(doc), ["-d"]))
    row("stdin offset is left alone when INPUT is a file", "", offset(11, ["-e", small]))
    row("stdin is a socket", "", sock)
    row("stdin is a descriptor of a file unreadable by path", "", unreadable)
    row("stdin is an empty pipe with O_NONBLOCK", "", nonblocking)
    row("stdin closed, no INPUT", "DISC-007", closed([0], ["-e"]))
    row("stdin closed, INPUT is a file", "", closed([0], ["-e", small]))
    row("stdin and stdout closed, INPUT is a file, 66 KB of output", "DISC-007", closed([0, 1], ["-e", big]))
    row("stdout closed, small output", "DISC-006", closed([1], ["-e", small]))
    row("stderr closed, a conversion error", "", closed([2], ["-e", os.path.join(work, "missing.json")]))
    row("stderr closed, a usage error", "DISC-003", closed([2], ["--bogus"]))
    row("stderr closed, a success line to write", "DISC-003", closed([2], ["-e", small, "-o", os.path.join(work, "out.toon")]))
    row("stdout is /dev/full", "DISC-006", full(1, ["-e"], b'{"a":1}'))
    row("stderr is /dev/full, a conversion error", "DISC-003", full(2, ["-e"], b"{bad"))
    row("stderr is /dev/full, a usage error", "DISC-003", full(2, ["--bogus"], b""))
    new = [r["row"] for r in rows if r["status"] == "NEW"]
    summary = {"rows": len(rows), "same": sum(r["status"] == "SAME" for r in rows), "known": [r["disc"] + ": " + r["row"] for r in rows if r["status"] == "KNOWN"],
               "fixed": [r["row"] for r in rows if r["status"] == "FIXED"], "new": new, "work": work, "verdict": "PASS" if not new else "FAIL"}
    print(json.dumps(summary))
    return 0 if not new else 1


if __name__ == "__main__":
    sys.exit(main())
