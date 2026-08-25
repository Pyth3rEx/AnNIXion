#!/usr/bin/env bash
# Guards what a pull request from a fork can make CI fetch and build.
# flake.lock is rejected: a redirected `locked` entry reads as legitimate.
# flake.nix is reported only, since adding packages is ordinary contribution.
# MODE=annotate gates the lint job; MODE=markdown writes a note for the comment.
set -euo pipefail

: "${PR:?pull request number}"
: "${GITHUB_REPOSITORY:?owner/repo}"
MODE=${MODE:-annotate}

FILES=$(mktemp)
trap 'rm -f "$FILES"' EXIT
gh api "repos/$GITHUB_REPOSITORY/pulls/$PR/files" --paginate >"$FILES"

# A guard that cannot read the file list must not report the branch as clean.
if ! jq -e 'type == "array"' "$FILES" >/dev/null 2>&1; then
  if [ "${MODE:-annotate}" = markdown ]; then
    cat <<'MD'
> [!CAUTION]
> **The flake files could not be checked.** Read the diff for changes to
> `flake.nix` and `flake.lock` yourself before removing `needs triage`.

MD
    exit 0
  fi
  echo "::error::could not read the file list for PR #$PR; refusing to report it as clean."
  exit 1
fi

changed() {
  jq -e --arg f "$1" 'any(.[]; .filename == $f)' "$FILES" >/dev/null
}

lock=0
nix=0
inputs=0
changed flake.lock && lock=1
if changed flake.nix; then
  nix=1
  patch=$(jq -r '.[] | select(.filename == "flake.nix") | .patch // ""' "$FILES")
  # Package edits are routine; a touched input declaration is what needs reading.
  if printf '%s' "$patch" |
    grep -qE '^[+-][^+-].*(url[[:space:]]*=|inputs[[:space:]]*\.|follows[[:space:]]*=)'; then
    inputs=1
  fi
fi

if [ "$MODE" = markdown ]; then
  if [ "$lock" -eq 1 ]; then
    cat <<'MD'
> [!CAUTION]
> **This pull request changes `flake.lock`.** Nix fetches each input from its
> `locked` entry without checking it against `original`, so a redirected owner
> or rev still reads as legitimate. Do not remove `needs triage` until the lock
> is dropped from the branch.

MD
  elif [ "$inputs" -eq 1 ]; then
    cat <<'MD'
> [!CAUTION]
> **This pull request changes a flake input declaration.** CI fetches and builds
> whatever it resolves to. Read the `flake.nix` diff before removing
> `needs triage`.

MD
  elif [ "$nix" -eq 1 ]; then
    cat <<'MD'
> [!WARNING]
> **This pull request changes `flake.nix`.** Confirm it only touches packages
> and declares no new inputs.

MD
  fi
  exit 0
fi

if [ "$lock" -eq 1 ]; then
  echo "::error file=flake.lock,line=1::flake.lock must not be changed by a pull request from a fork. Nix fetches each input's 'locked' entry without checking it against 'original', so a redirected owner or rev still reads as legitimate here. Drop the file from this PR; the maintainer regenerates the lock separately."
fi
if [ "$inputs" -eq 1 ]; then
  echo "::warning file=flake.nix,line=1::This PR changes a flake input declaration. Review where the new input resolves to before removing 'needs triage' — CI fetches and builds it."
elif [ "$nix" -eq 1 ]; then
  echo "::warning file=flake.nix,line=1::This PR changes flake.nix. Confirm it only touches packages and adds no inputs before removing 'needs triage'."
fi
[ "$lock" -eq 0 ] && [ "$nix" -eq 0 ] && echo "this fork changes no flake files ✓"

exit "$lock"
