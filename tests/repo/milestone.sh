#!/usr/bin/env bash
# Fixture tests for milestone selection and the column it implies. Drives the
# real scripts via --select and --decide, so they cannot drift from them.
# No network, no Nix build.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/scripts/assign-milestone.sh"
COLUMN="$ROOT/.github/scripts/board-status.sh"
CLOSE="$ROOT/.github/scripts/close-milestone.sh"
WORKFLOW="$ROOT/.github/workflows/project.yml"
fails=0

report() {
  local name="$1" expected="$2" got="$3" rc="$4"

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

# New work lands on the furthest milestone, so the current release stays scoped.
check() {
  local got rc
  got="$("$SCRIPT" --select <<<"$3")"
  rc=$?
  report "$1" "$2" "$got" "$rc"
}

# The nearest milestone is the release being built.
check_near() {
  local got rc
  got="$("$SCRIPT" --select-nearest <<<"$3")"
  rc=$?
  report "$1" "$2" "$got" "$rc"
}

# Which column a triaged issue's milestone puts it in.
check_column() {
  local got rc
  got="$("$COLUMN" --decide "$3" "$4")"
  rc=$?
  report "$1" "$2" "$got" "$rc"
}

# ── Furthest: where new work lands ───────────────────────────────────────
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

# ── Nearest: the release being built ─────────────────────────────────────
check_near "nearest picks the lower version" "0.4.0 - Nebula" '[
  {"title":"0.4.0 - Nebula","number":1,"due_on":null},
  {"title":"0.5.0 - Aurora","number":2,"due_on":null}]'

check_near "nearest keeps 0.9.0 below 0.10.0" "0.9.0 - Nine" '[
  {"title":"0.10.0 - Ten","number":1,"due_on":null},
  {"title":"0.9.0 - Nine","number":2,"due_on":null}]'

# An unversioned milestone has no horizon, so it is never the next release.
check_near "nearest skips unversioned" "0.5.0 - Aurora" '[
  {"title":"Backlog","number":1,"due_on":null},
  {"title":"0.5.0 - Aurora","number":2,"due_on":null}]'

check_near "nearest falls back to due first" "Soon" '[
  {"title":"Later","number":1,"due_on":"2027-01-01T00:00:00Z"},
  {"title":"Soon","number":2,"due_on":"2026-01-01T00:00:00Z"}]'

check_near "nearest prefers a dated milestone" "Soon" '[
  {"title":"Someday","number":1,"due_on":null},
  {"title":"Soon","number":2,"due_on":"2026-01-01T00:00:00Z"}]'

# One open milestone is both the furthest and the next release.
check_near "single milestone is the next release" "0.4.0 - Nebula" '[
  {"title":"0.4.0 - Nebula","number":1,"due_on":null}]'

check_near "empty list" "" '[]'

# ── The column a milestone implies ───────────────────────────────────────
check_column "next release is Up next" "Up next" "0.4.0 - Nebula" "0.4.0 - Nebula"
check_column "a later release waits in Ready" "Ready" "0.5.0 - Aurora" "0.4.0 - Nebula"
check_column "no milestone waits in Ready" "Ready" "" "0.4.0 - Nebula"

# With no open milestone nothing is upcoming, so an unmilestoned issue must not
# match one by both sides being empty.
check_column "no open milestone waits in Ready" "Ready" "" ""

# ── Closing the milestone a release shipped ──────────────────────────────
# Nothing used to close it: the only path was a human doing it by hand, so
# 0.4.0 - Nebula stayed open after PR #140 merged (#143).
check_close() {
  local got rc
  got="$(MILESTONE="$3" "$CLOSE" --number <<<"$4")"
  rc=$?
  report "$1" "$2" "$got" "$rc"
}

check_close "the shipped milestone resolves to its number" "2" "0.5.0 - Abarus" '[
  {"title":"0.4.0 - Nebula","number":1},
  {"title":"0.5.0 - Abarus","number":2}]'

# Titles are free text. A prefix match would close the wrong release here.
check_close "a prefix does not match" "" "0.4.0" '[
  {"title":"0.4.0 - Nebula","number":1}]'

check_close "an unknown title closes nothing" "" "0.9.0 - Nowhere" '[
  {"title":"0.4.0 - Nebula","number":1}]'

check_close "no open milestones at all" "" "0.4.0 - Nebula" '[]'

# ── The workflow has to call it, and in the right place ──────────────────
# --nearest reads the open milestones to find the release being built. Run
# after the close it returns the next release; run before it, it returns the
# one that just shipped and scopes its own Ready work into Up next.
close_at=$(grep -n 'close-milestone.sh' "$WORKFLOW" | head -1 | cut -d: -f1)
nearest_at=$(grep -n 'assign-milestone.sh --nearest' "$WORKFLOW" | tail -1 | cut -d: -f1)

if [ -z "$close_at" ]; then
  printf 'FAIL project.yml never calls close-milestone.sh\n'
  fails=$((fails + 1))
elif [ -n "$nearest_at" ] && [ "$close_at" -lt "$nearest_at" ]; then
  printf 'ok   the milestone is closed before the next release is read\n'
else
  printf 'FAIL close-milestone.sh runs at line %s, after --nearest at %s\n' \
    "$close_at" "$nearest_at"
  fails=$((fails + 1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "milestone: all tests passed"
else
  echo "milestone: $fails test(s) failed"
fi
exit "$fails"
