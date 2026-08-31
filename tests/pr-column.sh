#!/usr/bin/env bash
# Fixture tests for the column a pull request lands in. Drives the real script
# through --decide, and checks project.yml still delivers it the events it
# decides on — a correct answer to an event that never arrives is the bug this
# covers. No network, no Nix build.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/.github/scripts/pr-column.sh"
WORKFLOW="$ROOT/.github/workflows/project.yml"
fails=0

report() {
  local name="$1" expected="$2" got="$3" rc="$4"

  if [ "$rc" -ne 0 ]; then
    printf 'FAIL %s: script exited %s\n' "$name" "$rc"
    fails=$((fails + 1))
  elif [ "$got" = "$expected" ]; then
    printf 'ok   %s → %s\n' "$name" "${got:-<nothing>}"
  else
    printf 'FAIL %s: expected %s, got %s\n' "$name" "${expected:-<nothing>}" "${got:-<nothing>}"
    fails=$((fails + 1))
  fi
}

# check <name> <expected> <action> <draft> <merged>
check() {
  local got rc
  got="$("$SCRIPT" --decide "$3" "$4" "$5")"
  rc=$?
  report "$1" "$2" "$got" "$rc"
}

# ── Closing without merging retires the work ─────────────────────────────
# The board used to leave it In progress for good: nothing handled a close
# that was not a merge, so an abandoned pull request sat with the live work.
check "closed unmerged is done with" "Done" closed false false
check "a closed draft is done with too" "Done" closed true false

# A merge moves the issues it closes as well, and which column depends on the
# branch, so the merge jobs decide it and this says nothing.
check "a merge is not this script's call" "" closed false true

# ── A draft is not work in progress ──────────────────────────────────────
check "a draft opens in Ready" "Ready" opened true false
check "a pull request opens In progress" "In progress" opened false false
check "marking it ready starts the work" "In progress" ready_for_review false false
check "back to draft parks it again" "Ready" converted_to_draft true false

# GitHub sends draft: false with ready_for_review and true with
# converted_to_draft, but the action alone is enough either way.
check "ready_for_review outranks a stale draft flag" "In progress" ready_for_review true false

# ── The workflow has to deliver those events ─────────────────────────────
types="$(yq -r '.on.pull_request_target.types | join(" ")' "$WORKFLOW" 2>/dev/null)"
for t in closed ready_for_review converted_to_draft; do
  if [[ " $types " == *" $t "* ]]; then
    printf 'ok   project.yml listens for %s\n' "$t"
  else
    printf 'FAIL project.yml never receives %s, so no column can follow it\n' "$t"
    fails=$((fails + 1))
  fi
done

handler="$(yq -r '
  [ .jobs | to_entries[]
    | select(.value.if // "" | test("merged == false")) | .key ] | join(" ")' \
  "$WORKFLOW" 2>/dev/null)"

if [ -n "$handler" ]; then
  printf 'ok   a closed unmerged pull request is handled by %s\n' "$handler"
else
  printf 'FAIL no job acts on a pull request closed without merging\n'
  fails=$((fails + 1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "pr-column: all tests passed"
else
  echo "pr-column: $fails test(s) failed"
fi
exit "$fails"
