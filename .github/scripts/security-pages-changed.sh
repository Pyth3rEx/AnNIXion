#!/usr/bin/env bash
# Decides whether a regenerated set of security pages says anything new.
#
# The scan runs weekly and stamps every page with the time it ran, so a naive
# `git diff` is never empty and the history fills with commits that changed a
# clock. Worse, that history is the point: the committed pages double as a CVE
# timeline, and a timeline where every entry is a no-op tells you nothing.
#
#   security-pages-changed.sh <new-dir> <committed-dir>
#
# Exit 0 when something substantive changed (or the pages are new), 1 when only
# the timestamp moved. Touches nothing — the caller decides what to do.
set -uo pipefail

NEW=${1:?usage: security-pages-changed.sh <new-dir> <committed-dir>}
OLD=${2:?usage: security-pages-changed.sh <new-dir> <committed-dir>}

if [ ! -d "$NEW" ]; then
  printf 'security-pages-changed: %s does not exist\n' "$NEW" >&2
  exit 2
fi

# Only the timestamp itself, never the rest of the line: the same header also
# carries the finding and package counts, and those changing is exactly the
# thing worth committing.
normalise() {
  # shellcheck disable=SC2016  # the backticks are markdown, not a substitution
  sed -E 's/`[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} UTC`/`TIMESTAMP`/g' "$1"
}

# A first run has nothing to compare against.
if [ ! -d "$OLD" ]; then
  echo "new: no published pages yet"
  exit 0
fi

mapfile -t new_files < <(cd "$NEW" && find . -name '*.md' -type f -printf '%P\n' | sort)
mapfile -t old_files < <(cd "$OLD" && find . -name '*.md' -type f -printf '%P\n' | sort)

if [ "${new_files[*]-}" != "${old_files[*]-}" ]; then
  echo "changed: the set of pages differs"
  exit 0
fi

for f in "${new_files[@]}"; do
  if ! diff -q <(normalise "$NEW/$f") <(normalise "$OLD/$f") >/dev/null 2>&1; then
    echo "changed: $f"
    exit 0
  fi
done

echo "unchanged: only the timestamp moved"
exit 1
