#!/usr/bin/env bash
# Which column a milestone puts triaged work in. The nearest open milestone is
# the upcoming release, so its work is Up next; anything further out is Ready.
# See docs/dev.md.
#
#   board-status.sh <milestone-title>            resolves the release from the API
#   board-status.sh --decide <title> <upcoming>  no network, for the fixtures
set -euo pipefail

UPCOMING="Up next"
LATER="Ready"

decide() {
  local current="${1:-}" upcoming="${2:-}"
  if [ -n "$upcoming" ] && [ "$current" = "$upcoming" ]; then
    printf '%s' "$UPCOMING"
  else
    printf '%s' "$LATER"
  fi
}

if [ "${1:-}" = "--decide" ]; then
  decide "${2:-}" "${3:-}"
  exit 0
fi

decide "${1:-}" "$("$(dirname "$0")/assign-milestone.sh" --nearest)"
