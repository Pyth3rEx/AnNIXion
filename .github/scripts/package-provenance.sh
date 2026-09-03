#!/usr/bin/env bash
# Resolves who maintains a package and under what licence, for the packages a
# CVE scan actually flagged.
#
# vulnxscan reports a package name and a version and nothing about the people
# behind it. For an audit that is the missing half: a finding in a package with
# five named maintainers is a different risk from the same finding in one with
# none, and "unmaintained" is a fact worth printing rather than an empty cell.
#
#   package-provenance.sh [--names FILE] [--triage CSV] [--sbom CDX] ...
#
# Names accumulate from every source given. The two scanners disagree about what
# a package is called — vulnxscan reports CPE product names, the SBOM reports
# nix attribute names — so a page covering both needs both, deduplicated.
#
# Emits JSON on stdout: { "<name>": { license, maintainers[], homepage } | null }.
# null means the name did not resolve to a nixpkgs attribute.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAMES=$(mktemp)
trap 'rm -f "$NAMES" "${EXPR:-}"' EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    --names)
      cat "${2:?--names needs a file}" >>"$NAMES"
      shift 2
      ;;
    --triage)
      # Column 3 of vulnxscan's triage CSV, which is quoted.
      python3 -c 'import csv,sys
for r in csv.DictReader(open(sys.argv[1], newline="", encoding="utf-8")):
    if r.get("package"): print(r["package"])' "${2:?--triage needs a file}" >>"$NAMES"
      shift 2
      ;;
    --sbom)
      jq -r '.components[].name // empty' "${2:?--sbom needs a file}" >>"$NAMES"
      shift 2
      ;;
    *)
      # A bare path stays supported: it is how the fixtures drive this.
      cat "$1" >>"$NAMES"
      shift
      ;;
  esac
done

if [ ! -s "$NAMES" ]; then
  printf 'package-provenance: no package names given\n' >&2
  exit 2
fi

# One evaluation for every package rather than one per package: nix pays the
# nixpkgs eval cost once, and a scan flagging 200 packages would otherwise take
# minutes of repeated startup.
NAMES_JSON=$(jq -R -s 'split("\n") | map(select(length > 0)) | unique' <"$NAMES")

EXPR=$(mktemp)
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
