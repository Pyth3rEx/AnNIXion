#!/usr/bin/env bash
# Resolves who maintains a package and under what licence, for the packages a
# CVE scan actually flagged.
#
# vulnxscan reports a package name and a version and nothing about the people
# behind it. For an audit that is the missing half: a finding in a package with
# five named maintainers is a different risk from the same finding in one with
# none, and "unmaintained" is a fact worth printing rather than an empty cell.
#
#   package-provenance.sh <names-file>   one package name per line
#
# Emits JSON on stdout: { "<name>": { license, maintainers[], homepage } | null }.
# null means the name did not resolve to a nixpkgs attribute — vulnxscan reports
# CPE product names, which do not all match attribute paths.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAMES_FILE=${1:?usage: package-provenance.sh <names-file>}
[ -r "$NAMES_FILE" ] || {
  printf 'package-provenance: cannot read %s\n' "$NAMES_FILE" >&2
  exit 2
}

# One evaluation for every package rather than one per package: nix pays the
# nixpkgs eval cost once, and a scan flagging 200 packages would otherwise take
# minutes of repeated startup.
NAMES_JSON=$(jq -R -s 'split("\n") | map(select(length > 0)) | unique' <"$NAMES_FILE")

EXPR=$(mktemp)
trap 'rm -f "$EXPR"' EXIT
cat >"$EXPR" <<NIX
let
  flake = builtins.getFlake "path:${ROOT}";
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  names = builtins.fromJSON ''${NAMES_JSON}'';

  # meta.license is a string, an attrset, or a list of either.
  licName =
    l:
    if builtins.isString l then
      l
    else if builtins.isList l then
      builtins.concatStringsSep ", " (map licName l)
    else
      (l.fullName or l.shortName or l.spdxId or "unknown");

  one =
    n:
    let
      p = pkgs.\${n} or null;
      r = builtins.tryEval (
        let
          m = p.meta or { };
        in
        {
          license = if m ? license then licName m.license else "";
          maintainers = map (x: {
            name = x.name or "";
            github = x.github or "";
          }) (m.maintainers or [ ]);
          homepage = if (m ? homepage) && builtins.isString m.homepage then m.homepage else "";
        }
      );
    in
    if p == null then null else (if r.success then r.value else null);
in
builtins.listToAttrs (
  map (n: {
    name = n;
    value = one n;
  }) names
)
NIX

nix eval --json --impure --file "$EXPR"
