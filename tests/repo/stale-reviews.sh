#!/usr/bin/env bash
# Fixture tests for when an unanswered review goes stale. Drives the real script
# through --decide, so the thresholds cannot drift from it. No network.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/scripts/stale-reviews.sh"
NOW="2026-03-01T12:00:00Z"
fails=0

# Days before NOW, so a case reads as its age rather than a date.
ago() { date -u -d "$NOW - $1 days" +%Y-%m-%dT%H:%M:%SZ; }

check() {
  local name="$1" expected="$2" review="$3" activity="${4:--}" got rc
  got=$("$SCRIPT" --decide "$review" "$activity" "$NOW")
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAIL %s: script exited %s\n' "$name" "$rc"
    fails=$((fails + 1))
  elif [ "$got" = "$expected" ]; then
    printf 'ok   %s → %s\n' "$name" "$got"
  else
    printf 'FAIL %s: expected %s, got %s\n' "$name" "$expected" "$got"
    fails=$((fails + 1))
  fi
}

# ── The clock runs from the review ─────────────────────────────────────────
check "fresh review is left alone"        none  "$(ago 5)"
check "day before the warning"            none  "$(ago 20)"
check "warning lands on the threshold"    warn  "$(ago 21)"
check "still only warned at 29 days"      warn  "$(ago 29)"
check "closes on the threshold"           close "$(ago 30)"
check "long overdue still closes"         close "$(ago 90)"

# ── Anything from the author resets it ─────────────────────────────────────
check "a reply the next day"              none  "$(ago 90)" "$(ago 89)"
check "a reply just before now"           none  "$(ago 90)" "$(ago 1)"
check "activity predating the review"     close "$(ago 40)" "$(ago 41)"
check "activity in the warning window"    none  "$(ago 25)" "$(ago 24)"

# ── No activity recorded at all ────────────────────────────────────────────
check "no activity, past the deadline"    close "$(ago 45)" "-"
check "no activity, still fresh"          none  "$(ago 3)"  "-"

echo
if [ "$fails" -eq 0 ]; then
  echo "stale-reviews: all tests passed"
else
  echo "stale-reviews: $fails test(s) failed"
fi
exit "$fails"
