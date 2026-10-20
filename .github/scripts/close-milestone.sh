#!/usr/bin/env bash
# close-milestone.sh — close the milestone a release just shipped.
#
# Nothing else does: pr-merged-main moved everything to Done and scoped the
# next release, but left the shipped milestone open for someone to close by
# hand (#143). Closing it here also makes --nearest correct in the steps that
# follow, which read the open milestones to find the release being built —
# while the shipped one is still open, it is the one they find.
#
#   close-milestone.sh            closes MILESTONE, resolved against the API
#   close-milestone.sh --number   milestone number for MILESTONE, list on stdin
#
# Reads MILESTONE from the environment. Needs GH_TOKEN with issues:write.
set -euo pipefail

# Titles are free text, so the match is exact and done by jq rather than by
# a grep that a milestone named "0.4.0" would also satisfy from "0.4.0 - X".
number_for() {
  jq -r --arg title "${MILESTONE:-}" \
    'map(select(.title == $title)) | first | .number // empty'
}

if [ "${1:-}" = "--number" ]; then
  number_for
  exit 0
fi

: "${MILESTONE:?milestone title}"

NUMBER="$(gh api "repos/$GITHUB_REPOSITORY/milestones?state=open&per_page=100" \
  | number_for)"

if [ -z "$NUMBER" ]; then
  echo "no open milestone titled '$MILESTONE' — nothing to close"
  exit 0
fi

gh api --method PATCH \
  "repos/$GITHUB_REPOSITORY/milestones/$NUMBER" \
  -f state=closed > /dev/null

echo "milestone '$MILESTONE' (#$NUMBER) closed"
