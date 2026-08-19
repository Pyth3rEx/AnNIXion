#!/usr/bin/env bash
#
# assign-milestone.sh — put an issue or PR on the upcoming milestone.
# The upcoming one is the open milestone due soonest; undated milestones sort
# last, and the lowest number breaks a tie. An existing milestone is left alone.
#
# Reads NUMBER and HAS_MILESTONE from the environment. Needs GH_TOKEN.

set -euo pipefail

: "${NUMBER:?issue or pull request number}"

if [ "${HAS_MILESTONE:-false}" = "true" ]; then
  echo "#$NUMBER already has a milestone"
  exit 0
fi

MILESTONE="$(gh api "repos/$GITHUB_REPOSITORY/milestones?state=open&per_page=100" --jq '
  [ .[] | {title, number, due: (.due_on // "9999-12-31T00:00:00Z")} ]
  | sort_by(.due, .number) | .[0].title // empty')"

if [ -z "$MILESTONE" ]; then
  echo "no open milestone — leaving #$NUMBER unassigned"
  exit 0
fi

gh issue edit "$NUMBER" --repo "$GITHUB_REPOSITORY" --milestone "$MILESTONE"
echo "#$NUMBER → $MILESTONE"
