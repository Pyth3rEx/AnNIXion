#!/usr/bin/env bash
# Runs every linter and reports each finding as a GitHub annotation.
#
# Runs the same way locally and in CI. Every tool runs even if an earlier one
# fails, so one pass reports everything rather than one problem at a time.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

status=0

# GitHub renders these on the diff. Outside Actions they are just log lines.
annotate() {
  printf '::error file=%s,line=%s,col=%s,title=%s::%s\n' "$1" "$2" "$3" "$4" "$5"
}

section() {
  printf '\n\033[1m── %s ─────────────────────────────────\033[0m\n' "$1"
}

mapfile -t nix_files < <(git ls-files '*.nix')
mapfile -t sh_files < <(git ls-files '*.sh')
# The installer has no extension; git tracks it executable.
[ -f scripts/annixion-install ] && sh_files+=(scripts/annixion-install)

# ── nixfmt ───────────────────────────────────────────────────────────────────
# Passing a directory is deprecated, so the file list is explicit.
section "nixfmt"
if unformatted=$(nixfmt --check "${nix_files[@]}" 2>&1 >/dev/null); then
  echo "formatting ok"
else
  echo "$unformatted"
  # nixfmt reports one path per line; there is no line number to point at.
  while IFS= read -r line; do
    file=${line%%:*}
    [ -f "$file" ] && annotate "$file" 1 1 "nixfmt" "Not formatted. Run 'nixfmt $file'."
  done <<<"$unformatted"
  status=1
fi

# ── statix ───────────────────────────────────────────────────────────────────
# Lints disabled in statix.toml are excluded here too; it reads the config.
section "statix"
if statix_out=$(statix check . --format errfmt 2>/dev/null); then
  echo "no anti-patterns"
else
  echo "$statix_out"
  # ./path>line:col:severity:code:message
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file=${line%%>*}
    rest=${line#*>}
    IFS=: read -r ln col sev code msg <<<"$rest"
    annotate "${file#./}" "$ln" "$col" "statix ${sev}${code}" "$msg"
  done <<<"$statix_out"
  status=1
fi

# ── deadnix ──────────────────────────────────────────────────────────────────
# --fail is required: deadnix exits 0 even when it finds dead code.
# -L keeps the conventional { config, lib, pkgs, ... } module signature.
section "deadnix"
if deadnix --fail --no-lambda-pattern-names . >/dev/null 2>&1; then
  echo "no dead code"
else
  deadnix --no-lambda-pattern-names .
  deadnix --no-lambda-pattern-names --output-format json . 2>/dev/null |
    python3 -c '
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    doc = json.loads(line)
    for r in doc.get("results", []):
        print("%s\t%s\t%s\t%s" % (doc["file"].lstrip("./"), r["line"], r["column"], r["message"]))
' | while IFS=$'\t' read -r file ln col msg; do
    annotate "$file" "$ln" "$col" "deadnix" "$msg"
  done
  status=1
fi

# ── shellcheck ───────────────────────────────────────────────────────────────
section "shellcheck"
if shellcheck --severity=style "${sh_files[@]}" >/dev/null 2>&1; then
  echo "no findings"
else
  shellcheck --severity=style "${sh_files[@]}"
  # path:line:col: level: message [SCnnnn]
  shellcheck --severity=style --format=gcc "${sh_files[@]}" 2>/dev/null |
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      IFS=: read -r file ln col rest <<<"$line"
      annotate "$file" "$ln" "$col" "shellcheck" "${rest# }"
    done
  status=1
fi

section "result"
[ "$status" -eq 0 ] && echo "all linters clean" || echo "linters reported findings"
exit "$status"
