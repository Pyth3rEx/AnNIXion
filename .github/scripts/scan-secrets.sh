#!/usr/bin/env bash
# Wraps trufflehog's git scanner so ci.yml and a contributor's shell run the
# identical command. Only verified findings fail the run — this repo already
# carries an unverified hit (an example `http://user:password@proxy` URI in
# documentation) that would otherwise block every PR touching that file.
#
#   scan-secrets.sh --since <commit>   this PR's commits only (every PR, L0)
#   scan-secrets.sh --full             the whole history (dev/hotfix -> main)
set -euo pipefail

usage() {
  echo "usage: $0 --since <commit> | --full" >&2
  exit 2
}

[ $# -ge 1 ] || usage

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# No --no-update: nixpkgs' trufflehog is wrapped with it already, and the
# flag errors if given twice.
args=(git "file://$ROOT" --results=verified --fail)

case "$1" in
  --since)
    [ $# -eq 2 ] && [ -n "$2" ] || usage
    args+=(--since-commit="$2")
    ;;
  --full)
    [ $# -eq 1 ] || usage
    ;;
  *)
    usage
    ;;
esac

exec trufflehog "${args[@]}"
