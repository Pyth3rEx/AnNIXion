#!/usr/bin/env bash
# Posts the lint summary as a new comment at the bottom of the pull request,
# deleting the previous one so the feed carries exactly one and it stays the
# most recent entry. NOTE holds a flake warning derived from the pull request
# itself, so it is trustworthy even when the summary is not.
set -euo pipefail

: "${PR:?pull request number}"
SUMMARY=${SUMMARY:-}
NOTE=${NOTE:-}

MARKER='<!-- annixion-code-quality -->'

has_summary=0
has_note=0
[ -n "$SUMMARY" ] && [ -s "$SUMMARY" ] && has_summary=1
[ -n "$NOTE" ] && [ -s "$NOTE" ] && has_note=1

if [ "$has_summary" -eq 0 ] && [ "$has_note" -eq 0 ]; then
  echo "nothing to report"
  exit 0
fi

BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT
{
  echo "$MARKER"
  echo "## Code quality"
  echo
  [ "$has_note" -eq 1 ] && cat "$NOTE"
  if [ "$has_summary" -eq 1 ]; then
    cat "$SUMMARY"
    echo
    echo "_Errors and warnings block the merge; info-level findings do not._"
    echo "_Every finding is annotated on the diff._"
  else
    echo "_Linting did not complete, so there is no summary to report._"
  fi
} >"$BODY"

gh api "repos/$GITHUB_REPOSITORY/issues/$PR/comments" --paginate \
  --jq ".[] | select(.body | contains(\"$MARKER\")) | .id" |
  while read -r id; do
    [ -n "$id" ] || continue
    gh api -X DELETE "repos/$GITHUB_REPOSITORY/issues/comments/$id" --silent
    echo "removed previous summary $id"
  done

gh pr comment "$PR" --repo "$GITHUB_REPOSITORY" --body-file "$BODY"
