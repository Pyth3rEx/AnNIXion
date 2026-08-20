#!/usr/bin/env bash
# Posts the lint summary as a new comment at the bottom of the pull request,
# deleting the previous one so the feed carries exactly one and it stays the
# most recent entry.
set -euo pipefail

: "${PR:?pull request number}"
: "${SUMMARY:?path to the summary markdown}"

MARKER='<!-- annixion-code-quality -->'

if [ ! -f "$SUMMARY" ]; then
  echo "no summary at $SUMMARY"
  exit 0
fi

{
  echo "$MARKER"
  echo "## Code quality"
  echo
  cat "$SUMMARY"
  echo
  echo "_Errors and warnings block the merge; info-level findings do not._"
  echo "_Every finding is annotated on the diff._"
} >"$SUMMARY.body"

gh api "repos/$GITHUB_REPOSITORY/issues/$PR/comments" --paginate \
  --jq ".[] | select(.body | contains(\"$MARKER\")) | .id" |
  while read -r id; do
    [ -n "$id" ] || continue
    gh api -X DELETE "repos/$GITHUB_REPOSITORY/issues/comments/$id" --silent
    echo "removed previous summary $id"
  done

gh pr comment "$PR" --repo "$GITHUB_REPOSITORY" --body-file "$SUMMARY.body"
