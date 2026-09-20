#!/usr/bin/env bash
# clean-build-check: does the COMMIT build and convert, not only the working tree?
# A source file that .gitignore hides (round 10: port/stdin_open.c and .js matched port/*.c, port/*.js) is
# present in the author's tree and absent from every checkout: all gates pass locally and the published
# commit does not build. This exports <ref> with `git archive` into a fresh temp directory, builds the
# native binary and the JavaScript build THERE, and runs the corpus on the native lane from THERE.
# usage: clean-build-check.sh [<ref>]          (default HEAD; BEND_CLI honored, default `bend`)
# exit: 0 the ref builds and passes, 1 it does not, 2 usage. Last stdout line: JSON. The export is kept.
set -uo pipefail
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0; }
ref="${1:-HEAD}"
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo 'clean-build-check: not in a git repository' >&2; exit 2; }
sha="$(git -C "$root" rev-parse --short "$ref" 2>/dev/null)" || { echo "clean-build-check: unknown ref $ref" >&2; exit 2; }
read -r -a bend <<<"${BEND_CLI:-bend}"
work="$(mktemp -d "${TMPDIR:-/tmp}/clean-build.XXXXXX")"
git -C "$root" archive "$ref" | tar -x -C "$work" || { echo '{"ref":"'"$sha"'","verdict":"FAIL","step":"archive"}'; exit 1; }
cd "$work" || exit 1
step=native
if BEND_NO_TELEMETRY=1 "${bend[@]}" port/main.bend -o "$work/toon_clean" >"$work/build.log" 2>&1; then
  step=js
  if BEND_NO_TELEMETRY=1 "${bend[@]}" port/main.bend -o "$work/toon_clean.js" >>"$work/build.log" 2>&1; then
    step=conform
    line="$(./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- "$work/toon_clean" --threads 1 -- 2>/dev/null | tail -1)"
    passed="$(printf '%s' "$line" | python3 -c 'import json,sys; j=json.load(sys.stdin); print(j.get("passed",0), j.get("failed",0), j.get("verdict","?"))' 2>/dev/null)"
    read -r ok bad verdict <<<"${passed:-0 0 ?}"
    if [[ "$verdict" == PASS ]]; then
      printf '{"ref":"%s","export":"%s","native":"built","js":"built","conform_c1t":{"passed":%s,"failed":%s},"verdict":"PASS"}\n' "$sha" "$work" "$ok" "$bad"
      exit 0
    fi
    printf '{"ref":"%s","export":"%s","conform_c1t":{"passed":%s,"failed":%s},"verdict":"FAIL","step":"conform"}\n' "$sha" "$work" "${ok:-0}" "${bad:-0}"
    exit 1
  fi
fi
tail -3 "$work/build.log" >&2
printf '{"ref":"%s","export":"%s","verdict":"FAIL","step":"%s"}\n' "$sha" "$work" "$step"
exit 1
