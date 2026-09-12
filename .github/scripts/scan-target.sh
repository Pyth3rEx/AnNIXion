#!/usr/bin/env bash
# Makes one store path out of many, so a scanner can be pointed at a subset of a
# closure.
#
# vulnxscan takes a single TARGET and scans its runtime dependencies. The set
# this branch adds is many paths and is not itself closed under references, so
# there is nothing in the store that already names exactly it. A derivation
# built out of those paths gets them recorded as its references, which makes its
# runtime closure the union of theirs -- the smallest single target that covers
# everything added.
#
# It has to be builtins.storePath, not the paths as text. Nix records a
# reference only where the string carrying it has context, and a path read out
# of a file has none: the target builds, scans clean, and reports that a branch
# adds nothing wrong because its closure is one file. storePath is what makes
# each path a real input.
#
# It covers more than that too: their dependencies come along, and most of those
# were already in the base closure. That is the price of keeping vulnix, which
# is nix-only and refuses an SBOM. render-pr-cve.py filters the findings back
# down to the added packages.
#
#   scan-target.sh --paths FILE [--name NAME]
#
# Prints the built store path on stdout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATHS=""
NAME="annixion-added"

while [ $# -gt 0 ]; do
  case "$1" in
    --paths)
      PATHS=${2:?--paths needs a file}
      shift 2
      ;;
    --name)
      NAME=${2:?--name needs a name}
      shift 2
      ;;
    *)
      printf 'scan-target: unknown argument %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$PATHS" ] || [ ! -s "$PATHS" ]; then
  printf 'scan-target: no store paths given\n' >&2
  exit 2
fi

# Every line has to be a store path: the text becomes a derivation's output and
# anything else in it is either ignored or a scan of something unasked for.
while read -r line; do
  case "$line" in
    /nix/store/*) ;;
    "") ;;
    *)
      printf 'scan-target: %s is not a store path\n' "$line" >&2
      exit 2
      ;;
  esac
done <"$PATHS"

PATHS=$(cd "$(dirname "$PATHS")" && printf '%s/%s' "$PWD" "$(basename "$PATHS")")

EXPR=$(mktemp)
trap 'rm -f "$EXPR"' EXIT
cat >"$EXPR" <<NIX
let
  flake = builtins.getFlake "path:${ROOT}";
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;

  lines = builtins.split "\n" (builtins.readFile ${PATHS});
  paths = builtins.filter (s: builtins.isString s && s != "") lines;
in
pkgs.writeText "${NAME}" (builtins.concatStringsSep "\n" (map builtins.storePath paths))
NIX

nix build --impure --no-link --print-out-paths --file "$EXPR"
