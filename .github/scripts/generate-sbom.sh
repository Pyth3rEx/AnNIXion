#!/usr/bin/env bash
# Builds the supply-chain artifacts published with each release.
#
# Two SBOMs, deliberately not merged. The runtime one is the operational
# artifact: it is what a vulnerability scanner should read, and a finding in it
# is a finding that can block an operator. The buildtime one is a superset —
# every tool, source archive and patch that touched the build, most of which
# never ships — and is a reference rather than a verdict. Merging them would
# put compiler CVEs on the operator's page, where they are noise.
#
#   generate-sbom.sh [--out-dir DIR]   writes both SBOMs and the readable index
#   generate-sbom.sh --name            lists the assets, one per line, no network
#
# --name takes no network, so tests/sbom.sh can drive the real script.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET=${SBOM_TARGET:-"$ROOT#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel"}
VERSION=${SBOM_VERSION:-$(tr -d '\r\n' <"$ROOT/VERSION")}
OUT_DIR=$PWD

runtime_name() { printf 'annixion-%s.cdx.json\n' "$1"; }
buildtime_name() { printf 'annixion-%s.buildtime.cdx.json\n' "$1"; }
page_name() { printf 'annixion-%s.supply-chain.md\n' "$1"; }

if [ "${1:-}" = "--name" ]; then
  runtime_name "$VERSION"
  buildtime_name "$VERSION"
  page_name "$VERSION"
  exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --out-dir)
      OUT_DIR=${2:?--out-dir needs a directory}
      shift 2
      ;;
    *)
      printf 'generate-sbom: unknown argument %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

# Given a bare store path sbomnix cannot reach nixmeta and falls back to a
# minimum attribute set — the SBOM ships with no licences, which is most of its
# non-security value gone. It has to be a flakeref.
case "$TARGET" in
  /nix/store/*)
    printf 'generate-sbom: %s is a store path; pass a flakeref or the SBOM loses its licence data\n' \
      "$TARGET" >&2
    exit 1
    ;;
esac

mkdir -p "$OUT_DIR"
OUT_DIR=$(cd "$OUT_DIR" && pwd)
RUNTIME="$OUT_DIR/$(runtime_name "$VERSION")"
BUILDTIME="$OUT_DIR/$(buildtime_name "$VERSION")"
PAGE="$OUT_DIR/$(page_name "$VERSION")"

# sbomnix writes sbom.spdx.json, sbom.csv and a ~12 MB http_cache.sqlite into
# the working directory whatever was asked for. Run it somewhere disposable and
# name every output, or contributors find these in their trees.
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

scan() {
  local out=$1
  shift
  (
    cd "$SCRATCH"
    sbomnix "$TARGET" "$@" \
      --cdx "$out" \
      --csv "$SCRATCH/sbom.csv" \
      --spdx "$SCRATCH/sbom.spdx.json"
  )
}

cyclonedx_or_die() {
  local f=$1 label=$2
  if ! jq -e '.bomFormat == "CycloneDX"' "$f" >/dev/null 2>&1; then
    printf 'generate-sbom: the %s SBOM is not a CycloneDX document\n' "$label" >&2
    exit 1
  fi
  if [ "$(jq '.components | length' "$f")" -eq 0 ]; then
    printf 'generate-sbom: the %s SBOM lists no components\n' "$label" >&2
    exit 1
  fi
}

printf 'Scanning %s (runtime)\n' "$TARGET"
scan "$RUNTIME"
cyclonedx_or_die "$RUNTIME" runtime

# The degraded fallback is silent otherwise: a well-formed SBOM, right component
# count, no licences on any of them. Only the runtime scan is held to this —
# two thirds of the build closure is bootstrap plumbing, patches and tarballs
# that legitimately carry no licence.
if [ "$(jq '[.components[] | select(.licenses != null and (.licenses | length > 0))] | length' "$RUNTIME")" -eq 0 ]; then
  printf 'generate-sbom: no component in the runtime SBOM carries a licence — sbomnix fell back to its minimum attribute set\n' >&2
  exit 1
fi

printf 'Scanning %s (buildtime)\n' "$TARGET"
scan "$BUILDTIME" --buildtime
cyclonedx_or_die "$BUILDTIME" buildtime

# --buildtime emits runtime_and_buildtime: the build closure contains the
# runtime one. If that stops holding, the readable page is comparing two sets
# that no longer nest, and its "does not ship" half is wrong.
#
# A runtime component counts as present if either its bom-ref (deriver) or any
# of its nix:output_path values (a multi-output derivation carries one per
# output) turns up on the buildtime side. bom-ref alone is not enough: a
# fixed-output derivation (a plain URL fetch, burpsuite.jar among them) can
# have more than one valid deriver for the same output — two derivations
# differing only in, say, the curl used to fetch it still hash to the same
# fixed output — and Nix's local store records whichever deriver it last saw,
# which need not be the one this specific buildtime graph reaches even though
# the output itself demonstrably is there. Output path alone is not enough
# either: it only names one output of what may be several, so two components
# for the same multi-output derivation can legitimately carry disjoint
# single-output paths. Either match is sufficient; only failing both means
# the runtime output is actually missing from the build closure.
runtime_n=$(jq '.components | length' "$RUNTIME")
buildtime_n=$(jq '.components | length' "$BUILDTIME")
missing=$(jq -n --slurpfile r "$RUNTIME" --slurpfile b "$BUILDTIME" '
  def outpaths: (.properties // []) | [.[] | select(.name == "nix:output_path") | .value];
  ($b[0].components | map(.["bom-ref"]) | reduce .[] as $x ({}; .[$x] = true)) as $have_ref
  | ($b[0].components | map(outpaths) | add // [] | reduce .[] as $x ({}; .[$x] = true)) as $have_out
  | [$r[0].components[] | select(
      ($have_ref[.["bom-ref"]] | not)
      and ((outpaths | any(. as $p | $have_out[$p])) | not)
    )] | length
')
if [ "$missing" -ne 0 ]; then
  printf 'generate-sbom: %s runtime component(s) are absent from the build closure — the two SBOMs no longer nest\n' \
    "$missing" >&2
  exit 1
fi

# Recomputed every release rather than quoted from a past one: the closure only
# ever moves, and a stale figure in a release body is worse than none.
STORE_PATH=$(nix path-info "$TARGET" | head -1)
CLOSURE_PATHS=$(nix path-info -r "$STORE_PATH" | wc -l)
CLOSURE_BYTES=$(nix path-info -S --json --json-format 1 "$STORE_PATH" |
  jq '[.. | objects | select(has("closureSize")) | .closureSize] | first')
CLOSURE_HUMAN=$(awk -v b="$CLOSURE_BYTES" 'BEGIN {
  if (b >= 1073741824) printf "%.2f GiB", b / 1073741824; else printf "%.1f MiB", b / 1048576
}')

# Stamped into the documents themselves, so an archived SBOM still reports the
# closure it describes once the release body is the only other record.
stamp() {
  local f=$1 tmp
  tmp=$(mktemp)
  jq --arg v "$VERSION" \
    --arg paths "$CLOSURE_PATHS" \
    --arg bytes "$CLOSURE_BYTES" \
    --arg human "$CLOSURE_HUMAN" \
    --arg store "$STORE_PATH" '
    .metadata.properties = ((.metadata.properties // []) + [
      { name: "annixion:version",             value: $v },
      { name: "annixion:closure_store_path",  value: $store },
      { name: "annixion:closure_store_paths", value: $paths },
      { name: "annixion:closure_size_bytes",  value: $bytes },
      { name: "annixion:closure_size",        value: $human }
    ])' "$f" >"$tmp"
  mv "$tmp" "$f"
}
stamp "$RUNTIME"
stamp "$BUILDTIME"

bash "$ROOT/.github/scripts/render-supply-chain.sh" \
  --runtime "$RUNTIME" --buildtime "$BUILDTIME" >"$PAGE"

printf '\nClosure   %s store paths, %s\n' "$CLOSURE_PATHS" "$CLOSURE_HUMAN"
printf 'Runtime   %-8s %s components\n' "$(du -h "$RUNTIME" | cut -f1)" "$runtime_n"
printf 'Buildtime %-8s %s components\n' "$(du -h "$BUILDTIME" | cut -f1)" "$buildtime_n"
printf 'Page      %-8s %s\n' "$(du -h "$PAGE" | cut -f1)" "$PAGE"
