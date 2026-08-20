#!/usr/bin/env bash
#
# assign-milestone.sh — put an issue or PR on the furthest open milestone.
# The furthest one is the highest version in the title, so with 0.4.0 and 0.5.0
# open, new work lands on 0.5.0. Titles without a version are only considered
# when nothing has one, and then the milestone due last wins. An existing
# milestone is left alone.
#
# Reads NUMBER and HAS_MILESTONE from the environment. Needs GH_TOKEN.
#
# With --select, reads the milestone list as JSON on stdin and prints the
# chosen title. tests/milestone.sh drives that, so the tests cover this
# selection itself rather than a copy of it.

set -euo pipefail

select_milestone() {
  local milestones="$1" chosen

  # sort -V compares version components numerically, so 0.10.0 beats 0.9.0 —
  # which a plain sort gets backwards. grep exits 1 when no title carries a
  # version at all, and pipefail would make that fatal before the fallback
  # below ever ran, so it is tolerated here.
  chosen="$(jq -r '.[].title' <<<"$milestones" |
    { grep -E '^v?[0-9]+(\.[0-9]+)*' || true; } |
    sort -V |
    tail -1)"

  # Nothing versioned: the milestone due last wins. An undated one counts as
  # furthest out, because it has no horizon.
  if [ -z "$chosen" ]; then
    chosen="$(jq -r '
      [ .[] | { title, number, due: (.due_on // "9999-12-31T00:00:00Z") } ]
      | sort_by(.due, .number) | last | .title // empty' <<<"$milestones")"
  fi

  printf '%s' "$chosen"
}

if [ "${1:-}" = "--select" ]; then
  select_milestone "$(cat)"
  exit 0
fi

: "${NUMBER:?issue or pull request number}"

if [ "${HAS_MILESTONE:-false}" = "true" ]; then
  echo "#$NUMBER already has a milestone"
  exit 0
fi

MILESTONES="$(gh api "repos/$GITHUB_REPOSITORY/milestones?state=open&per_page=100")"
MILESTONE="$(select_milestone "$MILESTONES")"

if [ -z "$MILESTONE" ]; then
  echo "no open milestone — leaving #$NUMBER unassigned"
  exit 0
fi

gh issue edit "$NUMBER" --repo "$GITHUB_REPOSITORY" --milestone "$MILESTONE"
echo "#$NUMBER → $MILESTONE"
