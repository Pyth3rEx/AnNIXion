#!/usr/bin/env bash
#
# closing-issues.sh — print the node ID of every issue a pull request closes,
# one per line.
#
# Prefers the closing keywords GitHub itself resolved, so the result matches
# what will actually be closed on merge. That list is populated asynchronously
# though, and a merge that happens before it resolves used to return nothing,
# leaving the issue stranded wherever it was (#169). So when it comes back
# empty the body is parsed for the same keywords and the numbers resolved by
# hand — the answer GitHub would have given, just earlier.
#
#   closing-issues.sh <pr-number>   node IDs, from the API
#   closing-issues.sh --parse       issue numbers from a body on stdin
#
# --parse is the pure half, for the fixtures in tests/repo/closing-issues.sh.

# GraphQL queries below use $variables that must not be shell-expanded.
# shellcheck disable=SC2016

set -euo pipefail

# ── Body parsing ──────────────────────────────────────────────────────────
# GitHub only honours a keyword that sits immediately before the reference,
# and ignores anything inside a fenced code block — a PR body quoting a diff
# or a log line is otherwise enough to invent a reference. Both the bare #N
# and the full-URL spelling count.
parse_body() {
  awk '
    /^[[:space:]]*```/ { fence = !fence; next }
    !fence            { print }
  ' \
    | grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]*:?[[:space:]]+(https://github\.com/[^/]+/[^/]+/issues/|#)[0-9]+' \
    | grep -oE '[0-9]+$' \
    | sort -un
}

if [ "${1:-}" = "--parse" ]; then
  parse_body
  exit 0
fi

PR="${1:?pull request number}"
OWNER="${GITHUB_REPOSITORY%/*}"
REPO="${GITHUB_REPOSITORY#*/}"

# One query for both halves: the resolved list, and the body to fall back on.
response="$(gh api graphql -f owner="$OWNER" -f repo="$REPO" -F pr="$PR" -f query='
  query($owner:String!, $repo:String!, $pr:Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        body
        closingIssuesReferences(first: 50) { nodes { id number } }
      }
    }
  }')"

resolved="$(jq -r \
  '.data.repository.pullRequest.closingIssuesReferences.nodes[].id' \
  <<< "$response")"

if [ -n "$resolved" ]; then
  printf '%s\n' "$resolved"
  exit 0
fi

echo "closing-issues: no resolved references for #$PR, parsing the body" >&2

numbers="$(jq -r '.data.repository.pullRequest.body // ""' <<< "$response" \
  | parse_body)"

if [ -z "$numbers" ]; then
  echo "closing-issues: the body names none either" >&2
  exit 0
fi

# Resolve each number, and keep only the ones that really are issues: the
# same keyword in front of a pull request number is not a closing reference.
while IFS= read -r number; do
  [ -n "$number" ] || continue
  id="$(gh api graphql -f owner="$OWNER" -f repo="$REPO" -F number="$number" -f query='
    query($owner:String!, $repo:String!, $number:Int!) {
      repository(owner: $owner, name: $repo) {
        issueOrPullRequest(number: $number) {
          ... on Issue { id }
        }
      }
    }' --jq '.data.repository.issueOrPullRequest.id // empty' 2>/dev/null || true)"
  if [ -n "$id" ]; then
    echo "closing-issues: #$number resolved from the body" >&2
    printf '%s\n' "$id"
  else
    echo "closing-issues: #$number is not an issue, skipped" >&2
  fi
done <<< "$numbers"
