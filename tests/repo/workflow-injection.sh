#!/usr/bin/env bash
# GitHub pastes a ${{ }} expression into the script text before bash sees it, so
# any expression carrying text a person can write becomes shell syntax — a PR
# body of `id` runs id. Values reach a run: block through env: instead, where
# they stay data. Anything in with:, if: or env: itself is fine; only run: is
# a shell.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fails=0

# node_id and sha are GitHub-minted and cannot hold shell syntax; the rest of
# an event payload is whatever somebody typed.
SAFE='node_id|github\.sha|github\.repository|github\.ref|github\.run_id|runner\.temp|runner\.os|secrets\.'

for f in "$ROOT"/.github/workflows/*.yml; do
  name=$(basename "$f")
  runs=$(yq -r '[.jobs[].steps[]? | select(.run) | .run] | .[]' "$f" 2>/dev/null) || {
    printf 'FAIL %s: could not be parsed\n' "$name"
    fails=$((fails + 1))
    continue
  }
  # shellcheck disable=SC2016  # the pattern is literal, not an expansion
  bad=$(grep -o '${{[^}]*}}' <<<"$runs" | grep -vE "$SAFE" | sort -u | tr '\n' ' ')
  if [ -n "$bad" ]; then
    printf 'FAIL %s: interpolated into a run: block — pass via env: instead\n     %s\n' \
      "$name" "$bad"
    fails=$((fails + 1))
  else
    printf 'ok   %s\n' "$name"
  fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "workflow-injection: all workflows pass values through env"
else
  echo "workflow-injection: $fails workflow(s) interpolate into a shell"
fi
exit "$fails"
