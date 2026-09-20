# toon — the proofs. The agent's file: imports the code and the laws and fills every law with
# `def Laws.<name>(params)`. Lemmas go above their first use. Gate:  bend PROOF.bend  →
# "All terms check." (state the unsafe count from the same output beside every parity claim).
import Base
import ./bignat.bend as BN
import ./text.bend as T
import ./json.bend as J
import ./decode.bend as D
import ./cli.bend as C
import ./LAWS.bend as Laws

# S1.4 the first arm of on.tok matches a stopped scan whatever the token is
def Laws.argv_stop_is_sticky(code, out, err, t):
  {==}

# S9.141 run scrutinizes the lines, then the bound, then the step: by cases on the first two, every
# arm that meets a failure returns it
def Laws.decode_error_ends_pass(ls, b, msg):
  match ls:
    case Nil{}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}
    case Con{l, rest}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}

# S4.202 the same cases; every arm that meets the root value returns it
def Laws.decode_root_ends_pass(ls, b, v):
  match ls:
    case Nil{}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}
    case Con{l, rest}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}

# S2.45 the first arm of step
def Laws.json_error_is_sticky(msg, el, ec, stack, depth, l, c, root, b):
  {==}

# S4.217 the first arm of close.msg
def Laws.lenient_body_never_fails(short, blank, surplus, tab, n, cnt):
  {==}

# S2.112 the second arm of scan.check
def Laws.lenient_scan_never_fails(tab, num, unit, indent):
  {==}

# S4.300 (1)
def Laws.encode_flag_wins(dec, has_in, e):
  {==}

# S4.300 (2)
def Laws.decode_flag_wins(has_in, e):
  {==}

# S4.303
def Laws.stdin_defaults_to_encode(e):
  {==}

# S4.314
def Laws.no_saved_line_without_savings(j, t):
  {==}

# S4.248 expand scrutinizes the value first: by cases on its constructor, every arm meets XVal{0n}
def Laws.expansion_cap_on_values(v, strict):
  match v:
    case J.JNull{}:
      {==}
    case J.JBool{b}:
      {==}
    case J.JNum{f}:
      {==}
    case J.JStr{s}:
      {==}
    case J.JArr{n, items}:
      {==}
    case J.JObj{entries}:
      {==}
    case J.JNil{}:
      {==}
    case J.JCons{head, tail}:
      {==}
    case J.JECons{key, quoted, val, tail}:
      {==}

# S4.248
def Laws.expansion_cap_on_merges(tgt, src, strict):
  {==}

# S7.21
def Laws.bn_add_carry():
  {==}

# S2.107
def Laws.depth_of_indent():
  {==}

# S2.107
def Laws.depth_with_indent_zero():
  {==}

# S4.317
def Laws.stats_estimate_small():
  {==}

# S4.310
def Laws.stats_estimate_empty():
  {==}

# S4.316
def Laws.stats_pct_6_25():
  {==}

# S4.316
def Laws.stats_pct_18_75():
  {==}

# S4.315
def Laws.stats_pct_double_rounding():
  {==}
