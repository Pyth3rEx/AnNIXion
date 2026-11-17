#!/usr/bin/env bash
# Fixture tests for the closing references read out of a pull request body.
# GitHub populates closingIssuesReferences asynchronously, and a merge that
# lands before it resolves used to return nothing at all — the job stayed
# green and the issue stayed where it was (#169). The fallback is what has to
# be right, so it is driven directly through --parse. No network.
# The fixture bodies below are literal text, '#' and all.
# shellcheck disable=SC2016
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/scripts/closing-issues.sh"
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

# check <name> <expected, space separated> <body>
check() {
  local got
  got="$(printf '%s' "$3" | "$SCRIPT" --parse | tr '\n' ' ' | sed 's/ $//')"
  report "$1" "$2" "$got"
}

# ── The spellings GitHub honours ─────────────────────────────────────────
check "closes" "151" "Closes #151"
check "closed" "151" "closed #151"
check "close" "151" "close #151"
check "fixes" "151" "Fixes #151"
check "fixed" "151" "fixed #151"
check "fix" "151" "fix #151"
check "resolves" "151" "Resolves #151"
check "resolved" "151" "resolved #151"
check "resolve" "151" "resolve #151"
check "a colon after the keyword" "151" "Closes: #151"
check "the full URL spelling" "7" \
  "Resolves https://github.com/Pyth3rEx/AnNIXion/issues/7"

# ── What it must not pick up ─────────────────────────────────────────────
# A bare mention is not a closing reference; GitHub does not treat it as one
# and neither should the fallback, or merging would retire unrelated work.
check "a bare mention" "" "See #151 for background"
check "a related-to mention" "" "Related to #151"
check "a prose sentence about an issue" "" "This is part of the #151 effort"

# A body quoting a diff, a log line or another PR's description is the way an
# invented reference would get in. GitHub ignores fenced blocks; so does this.
check "a reference inside a fence" "" "$(printf '```\nCloses #999\n```')"
check "a real reference outside a fence" "151" \
  "$(printf 'Closes #151\n\n```\nCloses #999\n```')"

# ── Several at once, deduplicated and ordered ────────────────────────────
check "two references" "42 151" "$(printf 'Closes #151\nFixes #42')"
check "the same one twice" "151" "$(printf 'Closes #151\nFixes #151')"
check "three on one line" "1 2 3" "closes #1, fixes #2, resolves #3"

# ── Nothing at all ───────────────────────────────────────────────────────
check "an empty body" "" ""
check "a body with no references" "" "Just a description."

# ── The workflow still has to deliver the events ─────────────────────────
# A correct fallback that nothing calls is the same bug in a new place.
if grep -q 'closing-issues.sh' "$WORKFLOW"; then
  printf 'ok   project.yml still calls the script\n'
else
  printf 'FAIL project.yml no longer calls closing-issues.sh\n'
  fails=$((fails + 1))
fi

# The second-order half of #169: an issue that never reached "In review" has
# to be retired at release too, or it stays "In progress" after shipping.
if grep -q -- '--from "In progress" --to Done --milestone' "$WORKFLOW"; then
  printf 'ok   the release retires In progress work on the shipped milestone\n'
else
  printf 'FAIL project.yml has no milestone-scoped In progress sweep\n'
  fails=$((fails + 1))
fi

echo
if [ "$fails" -gt 0 ]; then
  printf 'closing-issues: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'closing-issues: all checks passed\n'
