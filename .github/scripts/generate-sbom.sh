#!/usr/bin/env bash
# Builds the CycloneDX SBOM published as a release asset, so an operator can
# answer "what is actually in this ISO" without rebuilding the closure — which
# stops being possible once cache entries are collected and sources move.
#
#   generate-sbom.sh [--out-dir DIR]   writes annixion-<VERSION>.cdx.json
#   generate-sbom.sh --name            prints that filename and touches nothing
#
# --name takes no network, so tests/sbom.sh can drive the real script.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET=${SBOM_TARGET:-"$ROOT#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel"}
VERSION=${SBOM_VERSION:-$(tr -d '\r\n' <"$ROOT/VERSION")}
OUT_DIR=$PWD

asset_name() { printf 'annixion-%s.cdx.json' "$1"; }

if [ "${1:-}" = "--name" ]; then
  asset_name "$VERSION"
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
CDX="$OUT_DIR/$(asset_name "$VERSION")"

# sbomnix writes sbom.spdx.json, sbom.csv and a ~12 MB http_cache.sqlite into
# the working directory whatever was asked for. Run it somewhere disposable and
# name every output, or contributors find these in their trees.
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

printf 'Scanning %s\n' "$TARGET"
(
  cd "$SCRATCH"
  sbomnix "$TARGET" \
    --cdx "$CDX" \
    --csv "$SCRATCH/sbom.csv" \
    --spdx "$SCRATCH/sbom.spdx.json"
)

if ! jq -e '.bomFormat == "CycloneDX"' "$CDX" >/dev/null 2>&1; then
  printf 'generate-sbom: %s is not a CycloneDX document\n' "$CDX" >&2
  exit 1
fi

components=$(jq '.components | length' "$CDX")
if [ "$components" -eq 0 ]; then
  printf 'generate-sbom: %s lists no components\n' "$CDX" >&2
  exit 1
fi

# The degraded fallback is silent otherwise: a well-formed SBOM, right component
# count, no licences on any of them.
if [ "$(jq '[.components[] | select(.licenses != null and (.licenses | length > 0))] | length' "$CDX")" -eq 0 ]; then
  printf 'generate-sbom: no component in %s carries a licence — sbomnix fell back to its minimum attribute set\n' \
    "$CDX" >&2
  exit 1
fi

printf 'Wrote %s (%s components, %s)\n' \
  "$CDX" "$components" "$(du -h "$CDX" | cut -f1)"
