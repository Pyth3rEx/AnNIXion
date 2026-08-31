#!/usr/bin/env bash
# Which column a pull request belongs in, from the event that just fired.
# See docs/dev.md.
#
#   pr-column.sh                                  reads ACTION, DRAFT, MERGED
#   pr-column.sh --decide <action> <draft> <merged>   no environment, for the fixtures
set -euo pipefail

DRAFTED="Ready"
ACTIVE="In progress"
RETIRED="Done"

decide() {
  local action="${1:-}" draft="${2:-false}" merged="${3:-false}"

  if [ "$action" = closed ]; then
    # A merged pull request is retired by the jobs that also move the issues
    # it closes; which column that is depends on the branch it merged into,
    # so this says nothing rather than guessing.
    if [ "$merged" != true ]; then
      printf '%s' "$RETIRED"
    fi
    return 0
  fi

  # The action says what just changed, so it outranks the draft flag in the
  # payload beside it: a ready_for_review that still reads draft:true would
  # otherwise park a pull request somebody just put up for review.
  case "$action" in
    ready_for_review) printf '%s' "$ACTIVE"; return 0 ;;
    converted_to_draft) printf '%s' "$DRAFTED"; return 0 ;;
  esac

  if [ "$draft" = true ]; then
    printf '%s' "$DRAFTED"
  else
    printf '%s' "$ACTIVE"
  fi
}

if [ "${1:-}" = "--decide" ]; then
  decide "${2:-}" "${3:-}" "${4:-}"
  exit 0
fi

decide "${ACTION:-}" "${DRAFT:-false}" "${MERGED:-false}"
