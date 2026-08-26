#!/usr/bin/env bash
# Every job must say what its token may do. Left undeclared, a job inherits the
# repository default — which is a setting in a web UI, not in this tree, and can
# be widened without a commit. Declaring it here pins the ceiling to the code.
#
# A workflow-level block covers every job in it; a job may raise its own above
# that floor, as Build ISO does to publish a release.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fails=0

for f in "$ROOT"/.github/workflows/*.yml; do
  name=$(basename "$f")

  if ! yq -e '.' "$f" >/dev/null 2>&1; then
    printf 'FAIL %s: could not be parsed\n' "$name"
    fails=$((fails + 1))
    continue
  fi

  # Jobs left to the repository default: no floor above them and none of their own.
  # shellcheck disable=SC2016  # $floor is a yq binding, not a shell variable
  undeclared=$(yq -r '
    (.permissions // null) as $floor
    | [ .jobs | to_entries[]
        | select($floor == null and (.value.permissions // null) == null)
        | .key ] | join(", ")' "$f" 2>/dev/null)

  if [ -n "$undeclared" ]; then
    printf 'FAIL %s: no permissions on %s\n' "$name" "$undeclared"
    fails=$((fails + 1))
  else
    granted=$(yq -r '
      [ (.permissions // {} | to_entries[]),
        (.jobs | to_entries[] | .value.permissions // {} | to_entries[]) ]
      | map(select(.key != null and .key != "") | "\(.key):\(.value)")
      | unique | join(" ")' "$f" 2>/dev/null)
    printf 'ok   %-20s %s\n' "$name" "$granted"
  fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "workflow-permissions: every job declares what its token may do"
else
  echo "workflow-permissions: $fails workflow(s) leave a job undeclared"
fi
exit "$fails"
