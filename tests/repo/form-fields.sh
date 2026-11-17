#!/usr/bin/env bash
# Fixture tests for the Priority and Size the board reads off an issue form,
# and for the events that carry them there.
#
# Status is driven by seven events and two sweeps. Priority and Size used to
# be written once, in issue-opened, and never again — so the board's Status
# views kept up while its Priority views went stale, and an issue filed
# without the form (#172) never got either. The parser is the easy half; the
# wiring is the half that was actually wrong, so both are checked. No network.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PARSE="$ROOT/.github/scripts/parse-form-fields.py"
WORKFLOW="$ROOT/.github/workflows/project.yml"
fails=0

report() {
  local name="$1" expected="$2" got="$3"
  if [ "$got" = "$expected" ]; then
    printf 'ok   %s → %s\n' "$name" "${got:-<nothing>}"
  else
    printf 'FAIL %s: expected %s, got %s\n' \
      "$name" "${expected:-<nothing>}" "${got:-<nothing>}"
    fails=$((fails + 1))
  fi
}

# check <name> <expected "priority=X size=Y"> <body>
check() {
  local got
  got="$(BODY="$3" "$PARSE" | tr '\n' ' ' | sed 's/ $//')"
  report "$1" "$2" "$got"
}

form() {
  printf '### Priority\n\n%s\n\n### Size\n\n%s\n' "$1" "$2"
}

# ── The answers the form offers ──────────────────────────────────────────
check "a filled form" "priority=P1 size=S" \
  "$(form 'P1 — a core workflow is broken or badly degraded' 'S — a single file')"
check "the blocking priority" "priority=P0 size=XS" \
  "$(form 'P0 — blocks everything' 'XS — a line or two')"
check "the largest size" "priority=P2 size=XL" \
  "$(form 'P2 — annoyance, cosmetic, or nice to have' 'XL — sweeping')"

# ── Unanswered dropdowns ─────────────────────────────────────────────────
check "an unsized issue keeps its priority" "priority=P1 size=" \
  "$(form 'P1 — a core workflow is broken' '_Not sure — leaving for maintainer to size._')"
check "an explicit no-response" "priority= size=" \
  "$(form '_No response_' '_No response_')"

# ── A body that is not a form at all ─────────────────────────────────────
# #172 was written as prose. Nothing to read means nothing is set, which is
# correct — but it is also why that issue sits under no priority on the board.
check "prose with no headings" "priority= size=" \
  "$(printf '## Summary\n\nA stock install provides no dynamic loader.\n')"
check "an empty body" "priority= size=" ""

# A heading whose answer is not one of the options must not reach the board:
# project-sync.sh dies on an unknown option rather than setting anything.
check "an unrecognised answer" "priority= size=" \
  "$(form 'Urgent!' 'Biggish')"

# ── The events that carry them to the board ──────────────────────────────
# A parser nothing re-runs is the bug this file exists for.
if grep -qE '^\s*types: \[.*\bedited\b.*\]' "$WORKFLOW"; then
  printf 'ok   an edited issue is an event the workflow receives\n'
else
  printf 'FAIL project.yml does not trigger on issues: edited\n'
  fails=$((fails + 1))
fi

if grep -q 'issue-edited:' "$WORKFLOW"; then
  printf 'ok   there is a job for it\n'
else
  printf 'FAIL project.yml has no issue-edited job\n'
  fails=$((fails + 1))
fi

# Both jobs that read the form have to reach the board with what they read.
writes=$(grep -c -- '--priority' "$WORKFLOW")
if [ "$writes" -ge 2 ]; then
  printf 'ok   both the open and the edit write Priority (%s call sites)\n' "$writes"
else
  printf 'FAIL only %s --priority call site(s); the edit does not write one\n' "$writes"
  fails=$((fails + 1))
fi

# The open is guarded so a hand-set value survives; the edit must not be, or
# editing the form would change nothing.
if awk '/issue-edited:/,/# ── Triaged/' "$WORKFLOW" | grep -q -- '--only-if-empty'; then
  printf 'FAIL the edit is guarded by --only-if-empty and cannot update\n'
  fails=$((fails + 1))
else
  printf 'ok   the edit is not guarded by --only-if-empty\n'
fi

echo
if [ "$fails" -gt 0 ]; then
  printf 'form-fields: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'form-fields: all checks passed\n'
