#!/usr/bin/env bash
# Fixture tests for the prompt's responsive width ladder. Renders the theme the
# repository actually ships and asserts two things at every width: the top line
# never wraps, and a nix-shell stays marked.
#
# OMP_CACHE_DIR is redirected at a scratch directory on purpose. oh-my-posh
# caches per session, and a warm cache serves the *installed* config no matter
# what --config says — which would quietly test the deployed theme instead of
# this working tree.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fails=0

if ! command -v oh-my-posh >/dev/null 2>&1; then
  echo "prompt-width: oh-my-posh not on PATH — run inside 'nix develop'"
  exit 1
fi

# -p /tmp, not $TMPDIR: a long TMPDIR (CI runners, nix-shell) would inflate the
# path segment and wrap the line for reasons that have nothing to do with the
# ladder under test.
WORK="$(mktemp -d -p /tmp)"
trap 'rm -rf "$WORK"' EXIT
export OMP_CACHE_DIR="$WORK/cache"
mkdir -p "$OMP_CACHE_DIR"

THEME="$WORK/theme.json"
if ! nix eval --json --file "$ROOT/home/shell/omp-theme.nix" >"$THEME" 2>"$WORK/eval.err"; then
  echo "prompt-width: could not evaluate home/shell/omp-theme.nix"
  cat "$WORK/eval.err"
  exit 1
fi

# A scratch cwd keeps the run deterministic: no git segment, and a path of the
# ~20 characters the ladder in docs/zsh.md is calibrated for. docs/zsh.md is
# explicit that a much longer path can still wrap; that is by design, so the
# test pins the length rather than asserting against arbitrary paths.
cd "$WORK" || exit 1

# Zsh brackets non-printing runs in %{...%}; everything else occupies a cell.
measure() {
  python3 -c '
import re, sys, unicodedata
raw = sys.stdin.buffer.read().decode("utf-8", "replace")
lines = raw.split("\n")
out = []
for line in lines:
    line = re.sub(r"%\{.*?%\}", "", line, flags=re.S)
    line = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line)
    line = re.sub(r"\x1b\][^\a]*\a", "", line)
    width = sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in line)
    out.append(f"{width}\t{line}")
print("\n".join(out))
'
}

render() {
  oh-my-posh print primary --shell zsh --config "$THEME" --terminal-width "$1" 2>/dev/null
}

report() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" -eq 0 ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s: %s\n' "$name" "$detail"
    fails=$((fails + 1))
  fi
}

# The ladder's thresholds, and either side of each, so an off-by-one in a
# min_width is caught rather than averaged away by a coarse sweep.
widths=()
for w in $(seq 40 5 200); do widths+=("$w"); done
for t in 70 105 120 135 150 165; do
  widths+=("$((t - 1))" "$t" "$((t + 1))")
done

# ── The top line must stay one line, at every width ────────────────────────
unset IN_NIX_SHELL
wrapped=""
for w in "${widths[@]}"; do
  measured="$(render "$w" | measure)"
  top_width="$(printf '%s' "$measured" | head -1 | cut -f1)"
  lines="$(printf '%s\n' "$measured" | grep -c .)"
  if [ "${top_width:-0}" -gt "$w" ]; then
    wrapped="$wrapped ${w}(top=${top_width})"
  fi
  if [ "$lines" -gt 2 ]; then
    wrapped="$wrapped ${w}(lines=${lines})"
  fi
done
report "$([ -z "$wrapped" ] && echo 0 || echo 1)" \
  "top line never wraps, 40-200 columns" "wrapped at$wrapped"

# ── A nix-shell stays marked, at every width — the #77 regression ──────────
export IN_NIX_SHELL=impure
missing=""
for w in "${widths[@]}"; do
  if ! render "$w" | grep -q '❄'; then
    missing="$missing $w"
  fi
done
report "$([ -z "$missing" ] && echo 0 || echo 1)" \
  "nix-shell marker shown at every width" "missing at$missing"

# ── The session background flips, at every width — the #77 signal ─────────
# It is carried on user @ host, which sheds at no width, so it must hold all
# the way down where the ladder has stripped everything else.
export IN_NIX_SHELL=impure
unflipped=""
for w in "${widths[@]}"; do
  if ! render "$w" | grep -q '48;2;126;186;228'; then
    unflipped="$unflipped $w"
  fi
done
report "$([ -z "$unflipped" ] && echo 0 || echo 1)" \
  "session background is Nix blue inside a nix-shell" "not flipped at$unflipped"

# ── And is absent when the shell is not one ────────────────────────────────
unset IN_NIX_SHELL
present=""
for w in 80 140 200; do
  if render "$w" | grep -qE '❄|48;2;126;186;228'; then present="$present $w"; fi
done
report "$([ -z "$present" ] && echo 0 || echo 1)" \
  "no nix-shell marking outside one" "marked at$present"

echo
if [ "$fails" -eq 0 ]; then
  echo "prompt-width: all tests passed"
else
  echo "prompt-width: $fails test(s) failed"
fi
exit "$fails"
