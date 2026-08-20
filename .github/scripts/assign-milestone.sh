#!/usr/bin/env bash
# Puts an issue or PR on the furthest open milestone. See docs/dev.md.
# Reads NUMBER and HAS_MILESTONE from the environment. Needs GH_TOKEN.
# --select reads the milestone list as JSON on stdin and prints the choice.
set -euo pipefail

select_milestone() {
  local milestones="$1" chosen

  # sort -V is numeric per component, so 0.10.0 beats 0.9.0. grep exits 1 when
  # nothing is versioned, which pipefail would make fatal before the fallback.
  chosen="$(jq -r '.[].title' <<<"$milestones" |
    { grep -E '^v?[0-9]+(\.[0-9]+)*' || true; } |
    sort -V |
    tail -1)"

  # Undated counts as furthest out; it has no horizon.
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
