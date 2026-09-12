#!/usr/bin/env bash
# Renders the two SBOMs into one page a person can read.
#
# The split is the point. Part 1 is the installed closure — a vulnerability
# there is exposure. Part 2 is everything that touched the build and does not
# ship — a vulnerability there is provenance. Presented as one number they add
# up to something alarming and meaningless, so they are never added up: part 2
# is explicitly demoted on the page and excluded from the SBOM scanners read.
#
#   render-supply-chain.sh --runtime RT.cdx.json --buildtime BT.cdx.json
#
# Writes markdown to stdout. Pure — it reads two files and touches nothing.
set -euo pipefail

RUNTIME="" BUILDTIME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --runtime)
      RUNTIME=${2:?--runtime needs a file}
      shift 2
      ;;
    --buildtime)
      BUILDTIME=${2:?--buildtime needs a file}
      shift 2
      ;;
    *)
      printf 'render-supply-chain: unknown argument %s\n' "$1" >&2
      exit 2
      ;;
  esac
done
if [ ! -r "${RUNTIME:-}" ] || [ ! -r "${BUILDTIME:-}" ]; then
  printf 'render-supply-chain: need a readable --runtime and --buildtime SBOM\n' >&2
  exit 2
fi

# Shared jq vocabulary. Components are per-derivation, so the same package at
# the same version can appear several times; the page collapses those and the
# JSON keeps the fidelity.
# shellcheck disable=SC2016  # $n and $c are jq bindings, not shell variables
JQ_DEFS='
  def prop($n): (.metadata.properties // []) | map(select(.name == $n)) | (.[0].value // "");
  def cell: tostring | gsub("\\|"; "\\\\|");
  def licence:
    [ (.licenses // [])[]
      | (.license.id? // .license.name? // .expression?) ]
    | map(select(. != null)) | unique | join(", ");
  def pkglabel: .name + (if (.version // "") == "" then "" else " " + .version end);
  def is_patch: (.name // "") | test("[.](patch|diff)$");
  def is_source: (.name // "") | test("[.](tar([.](gz|xz|bz2|zst|lz))?|tgz|tbz2|zip|crate|gem|whl|jar)$");
  def is_package: ((.version // "") != "") and (is_patch | not) and (is_source | not);
'

q() { jq -r "$JQ_DEFS $1" "${@:2}"; }

VERSION=$(q 'prop("annixion:version")' "$RUNTIME")
STORE_PATH=$(q 'prop("annixion:closure_store_path")' "$RUNTIME")
CLOSURE_PATHS=$(q 'prop("annixion:closure_store_paths")' "$RUNTIME")
CLOSURE_SIZE=$(q 'prop("annixion:closure_size")' "$RUNTIME")
GENERATED=$(q '.metadata.timestamp // ""' "$RUNTIME")

RUNTIME_N=$(q '[.components[] | select((is_source or is_patch) | not) | pkglabel] | unique | length' "$RUNTIME")
counts=$(jq -r "$JQ_DEFS"'
  ($rt[0].components | map(.["bom-ref"])) as $ships
  | [ .components[] | select((.["bom-ref"] as $r | $ships | index($r)) | not) ]
  | { pkg: [ .[] | select(is_package) | pkglabel ] | unique | length,
      src: [ .[] | select(is_source)  | .name ] | unique | length,
      pat: [ .[] | select(is_patch)   | .name ] | unique | length,
      etc: [ .[] | select((is_package or is_source or is_patch) | not) | .name ] | unique | length }
  | "\(.pkg) \(.src) \(.pat) \(.etc)"' --slurpfile rt "$RUNTIME" "$BUILDTIME")
read -r BO_PKG BO_SRC BO_PAT BO_ETC <<<"$counts"

cat <<EOF
# AnNIXion ${VERSION} — supply chain

*Generated ${GENERATED} from \`${STORE_PATH}\`.*

| | |
|---|---|
| Installed closure | ${CLOSURE_PATHS} store paths, ${CLOSURE_SIZE} |
| **Runs on the system** | **${RUNTIME_N} packages** |
| Build-only, never installed | ${BO_PKG} packages, ${BO_SRC} source archives, ${BO_PAT} patches, ${BO_ETC} build steps |

This page has two halves, and they are deliberately never added together.

**Part 1 is what runs on the machine.** Everything in it is installed. A
vulnerability there is yours, and part 1 is what a scanner should be pointed at.

**Part 2 is what built the machine.** None of it is installed, none of it
executes after the build, and none of it is reachable by an attacker on a
running system. A CVE against a compiler in part 2 is a fact about provenance,
not an exposure — it does not belong in the same count as part 1, and it is not
grounds to hold a release. It is here because "which toolchain and which sources
produced this image" is worth being able to answer without reading two thousand
derivations.

Machine-readable equivalents ship alongside this file.
\`annixion-${VERSION}.cdx.json\` is part 1, and is the one scanners should read;
\`annixion-${VERSION}.buildtime.cdx.json\` is parts 1 and 2 together, carrying
the full \`dependsOn\` graph.

---

## Part 1 — Installed

The ${RUNTIME_N} packages present on a running system, at the versions this
release pins. This is the operational list.

| Package | Version | Licence |
|---|---|---|
EOF

q '[ .components[]
     | select((is_source or is_patch) | not)
     | { n: (.name | cell), v: ((.version // "") | cell), l: (licence | cell) } ]
   | unique_by(.n + " " + .v)
   | sort_by(.n | ascii_downcase)
   | .[] | "| \(.n) | \(.v) | \(.l) |"' "$RUNTIME"

cat <<EOF

---

## Part 2 — Build-only

> **Nothing in this part is installed.** These are the tools, sources and
> patches that produced the closure above. They are listed for provenance. A
> finding against anything here is not a vulnerability in a running AnNIXion
> system and should not be reported as one.

### Reach

How many separate builds each input fed directly. An input near the top of this
table touched most of the system, which is where build-side trust actually
concentrates — a far more useful thing to know about part 2 than any CVE count
over it.

| Build input | Builds fed | Installed too? |
|---|---:|---|
EOF

jq -r "$JQ_DEFS"'
  ($rt[0].components | map(.["bom-ref"])) as $ships
  | (reduce .components[] as $c ({}; .[$c["bom-ref"]] = ($c | pkglabel))) as $names
  | (reduce .components[] as $c ({};
      .[$c["bom-ref"]] = (($c["bom-ref"] as $r | $ships | index($r)) != null))) as $installed
  | [ .dependencies[]? | (.dependsOn // [])[] ]
  | group_by(.) | map({ ref: .[0], n: length })
  | map(select($names[.ref] != null))
  | map({ label: $names[.ref], n: .n, inst: ($installed[.ref] // false) })
  | group_by(.label)
  | map({ label: .[0].label, n: (map(.n) | add), inst: (map(.inst) | any) })
  | sort_by(-.n, .label) | .[0:60][]
  | "| \(.label | cell) | \(.n) | \(if .inst then "yes" else "no" end) |"' \
  --slurpfile rt "$RUNTIME" "$BUILDTIME"

cat <<EOF

*Top 60 by reach. The complete edge set is in the buildtime SBOM.*

<details>
<summary><strong>Build-only packages (${BO_PKG})</strong> — present at build time, absent from the installed system</summary>

| Package | Version | Licence |
|---|---|---|
EOF

jq -r "$JQ_DEFS"'
  ($rt[0].components | map(.["bom-ref"])) as $ships
  | [ .components[]
      | select((.["bom-ref"] as $r | $ships | index($r)) | not)
      | select(is_package)
      | { n: (.name | cell), v: ((.version // "") | cell), l: (licence | cell) } ]
  | unique_by(.n + " " + .v)
  | sort_by(.n | ascii_downcase)
  | .[] | "| \(.n) | \(.v) | \(.l) |"' --slurpfile rt "$RUNTIME" "$BUILDTIME"

cat <<EOF

</details>

<details>
<summary><strong>Source archives (${BO_SRC})</strong> — every archive fetched from outside the tree</summary>

EOF

jq -r "$JQ_DEFS"'
  ($rt[0].components | map(.["bom-ref"])) as $ships
  | [ .components[]
      | select((.["bom-ref"] as $r | $ships | index($r)) | not)
      | select(is_source) | (.name | cell) ]
  | unique | sort | .[] | "- `\(.)`"' --slurpfile rt "$RUNTIME" "$BUILDTIME"

cat <<EOF

</details>

<details>
<summary><strong>Patches (${BO_PAT})</strong> — every patch applied on the way</summary>

EOF

jq -r "$JQ_DEFS"'
  ($rt[0].components | map(.["bom-ref"])) as $ships
  | [ .components[]
      | select((.["bom-ref"] as $r | $ships | index($r)) | not)
      | select(is_patch) | (.name | cell) ]
  | unique | sort | .[] | "- `\(.)`"' --slurpfile rt "$RUNTIME" "$BUILDTIME"

cat <<EOF

</details>

---

## What this page does not tell you

- **Presence is not reachability.** Part 1 lists what is installed, not what is
  running or exposed. Services \`hardening.nix\` disables still appear here.
- **Part 2 is not a vulnerability surface.** It is provenance. Do not add its
  findings to part 1's.
- **The build closure is derivation-level.** A source archive appears under the
  name nixpkgs fetched it as, and that name is not a guarantee of its contents.
  The hashes that are such a guarantee are in \`flake.lock\` and the store paths.
- **Both halves are exact for this tag and no other.** The closure is pinned by
  \`flake.lock\`; a rebuild from a different lock is a different system.
EOF
