#!/usr/bin/env bash
# Fixture tests for milestone selection. Drives the real script via --select,
# so they cannot drift from it. No network, no Nix build.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/.github/scripts/assign-milestone.sh"
fails=0

check() {
  local name="$1" expected="$2" got rc
  got="$("$SCRIPT" --select <<<"$3")"
  rc=$?

  if [ "$rc" -ne 0 ]; then
    printf 'FAIL %s: script exited %s\n' "$name" "$rc"
    fails=$((fails + 1))
  elif [ "$got" = "$expected" ]; then
    printf 'ok   %s → %s\n' "$name" "${got:-<none>}"
  else
    printf 'FAIL %s: expected %s, got %s\n' "$name" "${expected:-<none>}" "${got:-<none>}"
    fails=$((fails + 1))
  fi
}

check "picks the higher version" "0.5.0 - Aurora" '[
  {"title":"0.4.0 - Nebula","number":1,"due_on":null},
  {"title":"0.5.0 - Aurora","number":2,"due_on":null}]'

# A plain sort puts these the wrong way round.
check "0.10.0 beats 0.9.0" "0.10.0 - Ten" '[
  {"title":"0.9.0 - Nine","number":1,"due_on":null},
  {"title":"0.10.0 - Ten","number":2,"due_on":null}]'

check "ignores creation order" "1.0.0 - One" '[
  {"title":"1.0.0 - One","number":9,"due_on":null},
  {"title":"0.4.0 - Nebula","number":10,"due_on":null}]'

# "Backlog" must not capture every new issue.
check "versioned beats unversioned" "0.5.0 - Aurora" '[
  {"title":"Backlog","number":1,"due_on":null},
  {"title":"0.5.0 - Aurora","number":2,"due_on":null}]'

# The path pipefail used to kill outright.
check "no versions falls back to due last" "Later" '[
  {"title":"Soon","number":1,"due_on":"2026-01-01T00:00:00Z"},
  {"title":"Later","number":2,"due_on":"2027-01-01T00:00:00Z"}]'

check "undated counts as furthest out" "Someday" '[
  {"title":"Soon","number":1,"due_on":"2026-01-01T00:00:00Z"},
  {"title":"Someday","number":2,"due_on":null}]'

check "single milestone" "0.4.0 - Nebula" '[
  {"title":"0.4.0 - Nebula","number":1,"due_on":null}]'

check "v prefix" "v2.0.0" '[
  {"title":"v1.0.0","number":1,"due_on":null},
  {"title":"v2.0.0","number":2,"due_on":null}]'

check "empty list" "" '[]'

echo
if [ "$fails" -eq 0 ]; then
  echo "milestone: all tests passed"
else
  echo "milestone: $fails test(s) failed"
fi
exit "$fails"
