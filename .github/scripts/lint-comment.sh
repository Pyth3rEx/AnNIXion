#!/usr/bin/env bash
# Posts the lint summary as one sticky comment on the pull request.
set -euo pipefail

: "${PR:?pull request number}"
: "${SUMMARY:?path to the summary markdown}"

if [ ! -f "$SUMMARY" ]; then
  echo "no summary at $SUMMARY"
  exit 0
fi

{
  echo "## Code quality"
  echo
  cat "$SUMMARY"
  echo
  echo "_Errors and warnings block the merge; info-level findings do not._"
  echo "_Every finding is annotated on the diff._"
} >"$SUMMARY.body"

gh pr comment "$PR" --repo "$GITHUB_REPOSITORY" \
  --body-file "$SUMMARY.body" --edit-last --create-if-none
