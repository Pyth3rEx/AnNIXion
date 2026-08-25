#!/usr/bin/env bash
# Puts an issue or PR on the furthest open milestone. See docs/dev.md.
# Reads NUMBER and HAS_MILESTONE from the environment. Needs GH_TOKEN.
#
#   --select          furthest milestone, list read as JSON on stdin
#   --select-nearest  nearest milestone, same input — the upcoming release
#   --nearest         nearest milestone, read from the API
set -euo pipefail

# $2 picks the end: 'furthest' (the default) or 'nearest'. Both orderings are
# the same, so they differ only in which end of the sorted list is taken.
select_milestone() {
  local milestones="$1" end="${2:-furthest}" chosen versioned

  # sort -V is numeric per component, so 0.10.0 beats 0.9.0. grep exits 1 when
  # nothing is versioned, which pipefail would make fatal before the fallback.
  versioned="$(jq -r '.[].title' <<<"$milestones" |
    { grep -E '^v?[0-9]+(\.[0-9]+)*' || true; } |
    sort -V)"

  if [ -n "$versioned" ]; then
    if [ "$end" = nearest ]; then
      chosen="$(head -1 <<<"$versioned")"
    else
      chosen="$(tail -1 <<<"$versioned")"
    fi
  else
    # Undated counts as furthest out; it has no horizon.
    chosen="$(jq -r --arg end "$end" '
      [ .[] | { title, number, due: (.due_on // "9999-12-31T00:00:00Z") } ]
      | sort_by(.due, .number)
      | (if $end == "nearest" then first else last end)
      | .title // empty' <<<"$milestones")"
  fi

  printf '%s' "$chosen"
}

open_milestones() {
  gh api "repos/$GITHUB_REPOSITORY/milestones?state=open&per_page=100"
}

case "${1:-}" in
  --select)         select_milestone "$(cat)" furthest; exit 0 ;;
  --select-nearest) select_milestone "$(cat)" nearest;  exit 0 ;;
  --nearest)        select_milestone "$(open_milestones)" nearest; exit 0 ;;
esac

: "${NUMBER:?issue or pull request number}"

if [ "${HAS_MILESTONE:-false}" = "true" ]; then
  echo "#$NUMBER already has a milestone"
  exit 0
fi

MILESTONE="$(select_milestone "$(open_milestones)" furthest)"

if [ -z "$MILESTONE" ]; then
  echo "no open milestone — leaving #$NUMBER unassigned"
  exit 0
fi

gh issue edit "$NUMBER" --repo "$GITHUB_REPOSITORY" --milestone "$MILESTONE"
echo "#$NUMBER → $MILESTONE"
