#!/usr/bin/env bash
# Closes pull requests the maintainer asked changes on and nobody answered.
#
# The clock starts at the most recent "changes requested" review and is reset by
# anything the author does afterwards — a push, a comment, a reply on the diff.
# A warning lands first, so the close is never the first anyone hears of it.
#
#   --decide <review> <last-author-activity|-> <now>   → close | warn | none
#
# --decide takes ISO-8601 timestamps and touches nothing, so tests/stale-reviews.sh
# can drive the real logic without a network.
set -uo pipefail

WARN_DAYS=${WARN_DAYS:-21}
CLOSE_DAYS=${CLOSE_DAYS:-30}
# Report the verdicts and touch nothing. Worth running first after any change
# to the thresholds — this closes other people's work.
DRY_RUN=${DRY_RUN:-false}
MARKER='<!-- annixion-stale-review -->'

secs() { date -u -d "$1" +%s 2>/dev/null; }

decide() {
  local review="$1" activity="$2" now="$3" r n age
  r=$(secs "$review") || return 1
  n=$(secs "$now") || return 1
  [ -n "$r" ] && [ -n "$n" ] || return 1

  # Anything from the author after the review is an answer, whatever it said.
  if [ "$activity" != "-" ] && [ -n "$activity" ]; then
    local a
    a=$(secs "$activity") || return 1
    [ "$a" -gt "$r" ] && { echo none; return 0; }
  fi

  age=$(((n - r) / 86400))
  if [ "$age" -ge "$CLOSE_DAYS" ]; then
    echo close
  elif [ "$age" -ge "$WARN_DAYS" ]; then
    echo warn
  else
    echo none
  fi
}

if [ "${1:-}" = "--decide" ]; then
  decide "${2:-}" "${3:--}" "${4:-}"
  exit $?
fi

: "${GITHUB_REPOSITORY:?owner/repo}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

gh pr list --repo "$GITHUB_REPOSITORY" --state open --limit 100 \
  --json number,isDraft --jq '.[] | select(.isDraft | not) | .number' |
  while read -r pr; do
    [ -n "$pr" ] || continue

    data=$(gh pr view "$pr" --repo "$GITHUB_REPOSITORY" \
      --json reviewDecision,author,reviews,comments,commits 2>/dev/null) || continue

    [ "$(jq -r '.reviewDecision' <<<"$data")" = "CHANGES_REQUESTED" ] || continue

    author=$(jq -r '.author.login' <<<"$data")
    review=$(jq -r '[.reviews[] | select(.state == "CHANGES_REQUESTED") | .submittedAt]
                    | sort | last // empty' <<<"$data")
    [ -n "$review" ] || continue

    # The author's own footprint: pushes, comments on the PR, replies on the diff.
    activity=$(jq -r --arg a "$author" '
      [ (.commits[]? | .committedDate),
        (.comments[]? | select(.author.login == $a) | .createdAt),
        (.reviews[]?  | select(.author.login == $a) | .submittedAt) ]
      | map(select(. != null)) | sort | last // "-"' <<<"$data")

    verdict=$(decide "$review" "$activity" "$NOW")
    printf '#%s (%s): review %s, last author activity %s → %s\n' \
      "$pr" "$author" "$review" "$activity" "$verdict"

    if [ "$DRY_RUN" = true ]; then
      continue
    fi

    case "$verdict" in
      warn)
        # One warning only; the marker is how a second run knows.
        if gh api "repos/$GITHUB_REPOSITORY/issues/$pr/comments" --paginate \
          --jq '.[].body' | grep -qF "$MARKER"; then
          echo "  already warned"
          continue
        fi
        {
          echo "$MARKER"
          printf 'Changes were requested on %s and there has been no reply since.\n\n' "$review"
          printf 'This pull request closes automatically after %s days without one. ' "$CLOSE_DAYS"
          printf 'Pushing a commit or leaving a comment resets the clock — and reopening is always fine if you come back to it.\n'
        } >"${RUNNER_TEMP:-/tmp}/stale-$pr.md"
        gh pr comment "$pr" --repo "$GITHUB_REPOSITORY" --body-file "${RUNNER_TEMP:-/tmp}/stale-$pr.md"
        ;;
      close)
        {
          echo "$MARKER"
          printf 'Closing: changes were requested on %s and nothing has answered them in %s days.\n\n' \
            "$review" "$CLOSE_DAYS"
          printf 'Nothing here is rejected — reopen whenever you pick it up again.\n'
        } >"${RUNNER_TEMP:-/tmp}/stale-$pr.md"
        gh pr comment "$pr" --repo "$GITHUB_REPOSITORY" --body-file "${RUNNER_TEMP:-/tmp}/stale-$pr.md"
        gh pr close "$pr" --repo "$GITHUB_REPOSITORY"
        ;;
    esac
  done
