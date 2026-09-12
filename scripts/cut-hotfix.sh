#!/usr/bin/env bash
# Cuts (or resets) the hotfix branch from main's current tip, with VERSION
# already bumped to the next patch — so the branch never needs the author to
# compute or remember what number comes next.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

git fetch origin main
BASE_VERSION=$(git show origin/main:VERSION)
IFS=. read -r major minor patch <<<"$BASE_VERSION"
NEW_VERSION="$major.$minor.$((patch + 1))"

git checkout -B hotfix origin/main
echo "$NEW_VERSION" >VERSION
git add VERSION
git commit -m "chore(hotfix): bump to $NEW_VERSION"

cat <<EOF
hotfix branch created at $NEW_VERSION (from main's $BASE_VERSION).

Before opening the hotfix -> main PR:
  1. Set RELEASE_NAME to a new codename (required, must differ from main's).
  2. git push --force -u origin hotfix
EOF
