#!/usr/bin/env bash
# The SBOM is the one release asset nobody looks at until the release is too old
# to rebuild, so the ways it fails all fail quietly: sbomnix given a store path
# still writes a well-formed CycloneDX document, with the right component count
# and no licences on any of them. These drive the real script with sbomnix
# stubbed, so the checks cost a second rather than a closure build.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/.github/scripts/generate-sbom.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
fails=0

report() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" -eq 0 ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s: %s\n' "$name" "$detail"
    fails=$((fails + 1))
  fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Stands in for sbomnix: writes whatever CycloneDX body $STUB_BODY names to the
# --cdx path, and reproduces the litter the real tool drops in its cwd.
mkdir -p "$TMP/bin"
cat >"$TMP/bin/sbomnix" <<'STUB'
#!/usr/bin/env bash
cdx=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cdx) cdx="$2"; shift 2 ;;
    --csv | --spdx) shift 2 ;;
    *) shift ;;
  esac
done
printf '%s' "${STUB_BODY:?}" >"$cdx"
: >http_cache.sqlite
: >sbom.spdx.json
: >sbom.csv
STUB
chmod +x "$TMP/bin/sbomnix"
export PATH="$TMP/bin:$PATH"

GOOD='{"bomFormat":"CycloneDX","components":[{"name":"openssl","licenses":[{"license":{"id":"Apache-2.0"}}]},{"name":"zlib"}]}'
NO_LICENCE='{"bomFormat":"CycloneDX","components":[{"name":"openssl"},{"name":"zlib"}]}'
EMPTY='{"bomFormat":"CycloneDX","components":[]}'
NOT_CDX='{"spdxVersion":"SPDX-2.3","components":[{"name":"openssl"}]}'

run() {
  STUB_BODY="$1" SBOM_VERSION=9.9.9 SBOM_TARGET="${2:-$ROOT#toplevel}" \
    bash "$SCRIPT" --out-dir "$TMP/out" >"$TMP/log" 2>&1
}

# ── The name the release asset carries ───────────────────────────────
name=$(SBOM_VERSION=1.2.3 bash "$SCRIPT" --name 2>/dev/null)
report "$([ "$name" = "annixion-1.2.3.cdx.json" ] && echo 0 || echo 1)" \
  "--name is the version-stamped asset name" "got \"$name\""

# VERSION is what CI stamps releases with; the SBOM has to agree with it or the
# asset does not match the tag it ships under.
name=$(bash "$SCRIPT" --name 2>/dev/null)
report "$([ "$name" = "annixion-$(tr -d '\r\n' <"$ROOT/VERSION").cdx.json" ] && echo 0 || echo 1)" \
  "--name reads VERSION" "got \"$name\""

# ── Store path vs flakeref ───────────────────────────────────────────
run "$GOOD" "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-nixos-system"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a store path is refused" "scanned it anyway, so the SBOM would ship without licences"

# ── The happy path ───────────────────────────────────────────────────
mkdir -p "$TMP/cwd"
STUB_BODY="$GOOD" SBOM_VERSION=9.9.9 SBOM_TARGET="$ROOT#toplevel" \
  bash -c 'cd "$1" && bash "$2" --out-dir "$3"' _ "$TMP/cwd" "$SCRIPT" "$TMP/out" >"$TMP/log" 2>&1
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "a well-formed SBOM is accepted" "$(tail -1 "$TMP/log")"
report "$([ -f "$TMP/out/annixion-9.9.9.cdx.json" ] && echo 0 || echo 1)" \
  "the asset lands in --out-dir" "nothing at $TMP/out/annixion-9.9.9.cdx.json"

# The whole point of naming every output path and scanning from a scratch
# directory: a contributor running this by hand gets no untracked files.
strays=$(find "$TMP/cwd" -mindepth 1 -printf '%P ' 2>/dev/null)
report "$([ -z "$strays" ] && echo 0 || echo 1)" \
  "nothing is written to the working directory" "left behind: $strays"

# ── The failures that are otherwise silent ───────────────────────────
run "$NO_LICENCE"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "an SBOM with no licence data is refused" "accepted sbomnix's minimum attribute set"

run "$EMPTY"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "an SBOM with no components is refused" "accepted an empty component list"

run "$NOT_CDX"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a non-CycloneDX document is refused" "accepted a document that is not CycloneDX"

# ── The wiring, which cannot be tried locally ────────────────────────
# The SBOM is generated in `check` because that job already builds the closure
# and separate jobs share no store; `iso` can only publish what it downloads.
check_steps=$(yq -r '.jobs.check.steps[] | (.name // "") + " " + (.uses // "") + " " + (.run // "")' "$WORKFLOW" 2>/dev/null)
iso_steps=$(yq -r '.jobs.iso.steps[] | (.name // "") + " " + (.uses // "") + " " + (.run // "")' "$WORKFLOW" 2>/dev/null)

report "$(grep -q 'generate-sbom.sh' <<<"$check_steps" && echo 0 || echo 1)" \
  "the check job generates the SBOM" "no step runs generate-sbom.sh"
report "$(grep -q 'upload-artifact' <<<"$check_steps" && echo 0 || echo 1)" \
  "the check job uploads it" "nothing hands the SBOM to the iso job"
report "$(grep -q 'download-artifact' <<<"$iso_steps" && echo 0 || echo 1)" \
  "the iso job downloads it" "the release job never receives the SBOM"
report "$(grep -q 'gh release create' <<<"$iso_steps" && grep -q 'SBOM_PATH' <<<"$iso_steps" && echo 0 || echo 1)" \
  "the release attaches it" "gh release create does not list the SBOM"
report "$(grep -q 'SHA256SUMS' <<<"$iso_steps" && echo 0 || echo 1)" \
  "the SBOM is covered by SHA256SUMS" "no checksum file covers the release assets"

# --no-link discards the closure the SBOM is taken from.
report "$(grep -q 'out-link result-toplevel' <<<"$check_steps" && echo 0 || echo 1)" \
  "the closure build keeps an out-link" "L2 still builds with --no-link"

echo
if [ "$fails" -gt 0 ]; then
  printf 'sbom: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "sbom: the release SBOM is generated, validated and published"
