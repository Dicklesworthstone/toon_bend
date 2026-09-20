# toon — Bend 2 port of the `toon` CLI (toon_rust 0.2.4). This file is the IO SHELL: it is the only
# file with IO in its types. It reads argv, reads the input as bytes, calls ONE pure function per
# step (cli.bend: parse, convert), writes the output and the stderr lines, and owns every exit code.
# Nothing here consults the original: the spec is docs/EXISTING_Toon_STRUCTURE.md, the oracle is
# goldens/.
#
# Check:  bend PROOF.bend           (laws)   — must print "All terms check."
# Run:    bend main.bend -- <args>  (interp) — then bend main.bend -o toon; ./toon -- <args>
# The compiled binary consumes --help, --threads and --gpu before `--` (DISC-001): pass `--` first.
import Base
import ./cli.bend as C
import ./text.bend as T

# S8.1 argv arrives as an affine list; the core works on shared lists
def args.copy(a: List<&1, String>, acc: List<&2, String>) -> List<&2, String>:
  match a:
    case Nil{}:
      List.reverse(&2, String, acc)
    case Con{w, rest}:
      args.copy(rest, w <> acc)

# S8.5, S8.6 what reading the input gave: every byte, or the platform's error number and text
type RB is Data:
  RBOk{bytes: List<&2, U32>}
  RBFail{errno: U32, text: String}

# S8.6 prepend a chunk to the bytes after it (two loops: reverse, then push back)
def chunk.onto(rev: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match rev:
    case Nil{}:
      acc
    case Con{b, rest}:
      chunk.onto(rest, b <> acc)

# S8.6 the chunks were collected newest first: join them into one byte list, oldest first
def chunks.join(chunks: List<&2, List<&2, U32>>, acc: List<&2, U32>) -> List<&2, U32>:
  match chunks:
    case Nil{}:
      acc
    case Con{c, rest}:
      chunks.join(rest, chunk.onto(List.reverse(&2, U32, c), acc))

# S8.5, S8.6 read to the end of the file, one chunk per step; an empty chunk is the end. The measure
# is a chunk budget far above any input (2^40 bytes).
def read.loop(budget: Nat, got: File & Result<&1, &1, U32 & String, List<&2, U32>>, chunks: List<&2, List<&2, U32>>) -> IO(RB):
  match budget:
    case 0n:
      IO.pure(RB, RBFail{27, "File too large"})
    case 1n+g:
      match got:
        case (f, Fail{(n, text)}):
          do IO<RB>:
            File.close(f)
            return RBFail{n, text}
        case (f, Done{Nil{}}):
          do IO<RB>:
            File.close(f)
            return RBOk{chunks.join(chunks, Nil{})}
        case (f, Done{Con{b, more}}):
          do IO<RB>:
            next : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
            read.loop(g, next, (b <> more) <> chunks)

# S8.6 open failures carry the platform's error number and text (S9.4–S9.6)
def read.opened(r: Result<&1, &1, U32 & String, File>) -> IO(RB):
  match r:
    case Fail{(n, text)}:
      IO.pure(RB, RBFail{n, text})
    case Done{f}:
      do IO<RB>:
        got : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
        read.loop(1048576n, got, Nil{})

# S8.5 standard input as a Base File: descriptor 0 ITSELF. Base has no stdin effect, and opening the
# path /dev/stdin makes a NEW open file description: a regular file is read again from byte 0 whatever
# the caller's offset is (wrong bytes, exit 0), a socket cannot be opened at all (ENXIO: every Node.js
# child process), a file that is no longer readable by path fails, and O_NONBLOCK is lost (round 7,
# R7-1..3, R7-8). This is the port's ONE custom effect, with a twin for every lane: stdin_open.c for the
# native binary, stdin_open.js for the JavaScript build and the interpreter.
def Stdin.open() -> IO(Result<&1, &1, U32 & String, File>):
  import "./stdin_open.c"
  import "./stdin_open.js"

# S8.5, S8.6 the whole input: the INPUT path as typed, or stdin
def read.input(has_in: Bool, input: String) -> IO(RB):
  match has_in:
    case True{}:
      do IO<RB>:
        r : Result<&1, &1, U32 & String, File> <- File.open(input, "r")
        read.opened(r)
    case False{}:
      do IO<RB>:
        r : Result<&1, &1, U32 & String, File> <- Stdin.open()
        read.opened(r)

# S9.17 `<description> (os error <errno>)`
def os.text(n: U32, text: String) -> String:
  text ++ " (os error " ++ U32.show(n) ++ ")"

# S9.4–S9.6, S9.12 the read failure names the path as typed, or stdin
def read.msg(has_in: Bool, input: String, n: U32, text: String) -> String:
  match has_in:
    case True{}:
      T.cat(["Failed to read file '", input, "': ", os.text(n, text)])
    case False{}:
      "Failed to read stdin: " ++ os.text(n, text)

# S5.108, S5.109 the statistics lines, when there are any
def put.stats(stats: String) -> IO(Unit):
  match stats:
    case SNil{}:
      IO.pure(Unit, Unit{})
    case SCon{c, rest}:
      IO.print_err(SCon{c, rest})

# S9.15, S10.3 a failed write to the -o file is reported with --stats (encode) or when the output is
# longer than 8192 bytes; otherwise it is silently lost and the run ends as a success
def wrote(r: Result<&1, &1, U32 & String, Unit>, loud: Bool, +o: C.Opts, stats: String) -> IO(Unit):
  match r loud:
    case Fail{(n, text)} True{}:
      IO.die(Unit, 1, T.cat(["Failed to write to file '", C.o.output(o), "': ", os.text(n, text)]))
    case _ _:
      do IO<Unit>:
        put.stats(stats)
        IO.print_err(C.success(o))

# S8.12 the file is closed whatever the write gave
def write.closed(res: File & Result<&1, &1, U32 & String, Unit>, loud: Bool, o: C.Opts, stats: String) -> IO(Unit):
  match res:
    case (f, r):
      do IO<Unit>:
        File.close(f)
        wrote(r, loud, o, stats)

# S8.12 write the whole text to the created file and close it
def write.file(f: File, out: String, loud: Bool, o: C.Opts, stats: String) -> IO(Unit):
  do IO<Unit>:
    res : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, out)
    write.closed(res, loud, o, stats)

# S8.11 create or truncate the -o path; S9.13 its failure
def write.opened(r: Result<&1, &1, U32 & String, File>, output: String, out: String, loud: Bool, o: C.Opts, stats: String) -> IO(Unit):
  match r:
    case Fail{(n, text)}:
      IO.die(Unit, 1, T.cat(["Failed to create file '", output, "': ", os.text(n, text)]))
    case Done{f}:
      write.file(f, out, loud, o, stats)

# S5.100–S5.102 the output goes to stdout, or to the -o file (then stdout receives nothing)
def put.out(has_out: Bool, +out: String, +o: C.Opts, stext: String) -> IO(Unit):
  match has_out:
    case False{}:
      do IO<Unit>:
        IO.write(out)
        put.stats(stext)
    case True{}:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, File> <- File.open(C.o.output(o), "w")
        write.opened(r, C.o.output(o), out, Bool.or(C.o.stats(o), Nat.is_gt(T.utf8.len(out, 0n), 8192n)), o, stext)

# S5.111 a runtime failure is its one line on stderr and exit code 1; nothing was written before it
def converted(r: C.CR, +o: C.Opts) -> IO(Unit):
  match r:
    case C.CErr{msg}:
      IO.die(Unit, 1, msg)
    case C.COk{out, stext}:
      put.out(C.o.has_out(o), out, o, stext)

# S8.7, S8.8 the conversion starts only after the whole input was read
def got.input(rb: RB, +o: C.Opts, spec: Bool) -> IO(Unit):
  match rb:
    case RBFail{n, text}:
      IO.die(Unit, 1, read.msg(C.o.has_in(o), C.o.input(o), n, text))
    case RBOk{bytes}:
      converted(C.convert(o, bytes, spec), o)

# S8.2 the numeric kill-switch: TOON_SPEC=1 makes every number take its spec twin (the bytes are the
# same either way; the switch exists so that the two can be compared on the whole corpus)
def spec.on(r: Result<&1, &1, U32 & String, String>) -> Bool:
  match r:
    case Done{v}:
      T.str_eq(v, "1")
    case Fail{e}:
      False{}

# S1.135 no input is read before the whole argv was accepted
def run.opts(+o: C.Opts) -> IO(Unit):
  do IO<Unit>:
    sw : Result<&1, &1, U32 & String, String> <- IO.get_env("TOON_SPEC")
    rb : RB <- read.input(C.o.has_in(o), C.o.input(o))
    got.input(rb, o, spec.on(sw))

# S1.20 help and version go to stdout with exit code 0; every argv error to stderr with exit code 2
def run(p: C.Parsed) -> IO(Unit):
  match p:
    case C.PExit{0n, out, err}:
      IO.write(out)
    case C.PExit{code, out, err}:
      IO.die(Unit, 2, err)
    case C.PRun{o}:
      run.opts(o)

# S8.1 the shell's entry: argv in, exit code out
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(C.parse(args.copy(args, Nil{})))
