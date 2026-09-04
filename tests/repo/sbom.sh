#!/usr/bin/env bash
# The SBOMs are the one release asset nobody looks at until the release is too
# old to rebuild, so the ways they fail all fail quietly: sbomnix given a store
# path still writes a well-formed CycloneDX document, with the right component
# count and no licences on any of them. These drive the real script with sbomnix
# and nix stubbed, so the checks cost a second rather than a closure build.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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
mkdir -p "$TMP/bin"

# Stands in for sbomnix: writes $STUB_RUNTIME or $STUB_BUILDTIME depending on
# which scan it was asked for, and reproduces the litter the real tool drops in
# its working directory whatever output paths it was given.
cat >"$TMP/bin/sbomnix" <<'STUB'
#!/usr/bin/env bash
cdx="" buildtime=false
while [ $# -gt 0 ]; do
  case "$1" in
    --cdx) cdx="$2"; shift 2 ;;
    --csv | --spdx) shift 2 ;;
    --buildtime) buildtime=true; shift ;;
    *) shift ;;
  esac
done
if [ "$buildtime" = true ]; then
  printf '%s' "${STUB_BUILDTIME:?}" >"$cdx"
else
  printf '%s' "${STUB_RUNTIME:?}" >"$cdx"
fi
: >http_cache.sqlite
: >sbom.spdx.json
: >sbom.csv
STUB

# The closure metrics come from the live store. Stubbed so the fixtures stay
# hermetic; the shapes match what nix actually returns.
cat >"$TMP/bin/nix" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = "path-info" ] || exit 0
shift
case " $* " in
  *" -r "*) printf '/nix/store/a\n/nix/store/b\n/nix/store/c\n' ;;
  *" -S "*) printf '{"/nix/store/x-toplevel":{"closureSize":25097156362}}\n' ;;
  *) printf '/nix/store/x-toplevel\n' ;;
esac
STUB
chmod +x "$TMP/bin/sbomnix" "$TMP/bin/nix"
export PATH="$TMP/bin:$PATH"

meta() {
  printf '"metadata":{"timestamp":"2026-01-01T00:00:00+00:00","properties":[{"name":"sbom_type","value":"%s"}]}' "$1"
}
RT_GOOD='{"bomFormat":"CycloneDX",'$(meta runtime_only)',"components":[
  {"bom-ref":"r1","name":"openssl","version":"3.5.0","licenses":[{"license":{"id":"Apache-2.0"}}]},
  {"bom-ref":"r2","name":"zlib","version":"1.3.1"}],
  "dependencies":[{"ref":"r1","dependsOn":["r2"]}]}'
BT_GOOD='{"bomFormat":"CycloneDX",'$(meta runtime_and_buildtime)',"components":[
  {"bom-ref":"r1","name":"openssl","version":"3.5.0","licenses":[{"license":{"id":"Apache-2.0"}}]},
  {"bom-ref":"r2","name":"zlib","version":"1.3.1"},
  {"bom-ref":"b1","name":"gcc","version":"15.2.0"}],
  "dependencies":[{"ref":"r1","dependsOn":["r2","b1"]}]}'
# Legitimate: two thirds of a real build closure is unlicensed plumbing.
BT_NO_LICENCE='{"bomFormat":"CycloneDX",'$(meta runtime_and_buildtime)',"components":[
  {"bom-ref":"r1","name":"openssl","version":"3.5.0"},
  {"bom-ref":"r2","name":"zlib","version":"1.3.1"},
  {"bom-ref":"b1","name":"gcc","version":"15.2.0"}],
  "dependencies":[{"ref":"r1","dependsOn":["b1"]}]}'
# Not legitimate: the build closure has to contain the runtime one.
BT_NOT_SUPERSET='{"bomFormat":"CycloneDX",'$(meta runtime_and_buildtime)',"components":[
  {"bom-ref":"r1","name":"openssl","version":"3.5.0","licenses":[{"license":{"id":"Apache-2.0"}}]},
  {"bom-ref":"b1","name":"gcc","version":"15.2.0"}],
  "dependencies":[{"ref":"r1","dependsOn":["b1"]}]}'
RT_NO_LICENCE='{"bomFormat":"CycloneDX",'$(meta runtime_only)',"components":[
  {"bom-ref":"r1","name":"openssl","version":"3.5.0"},
  {"bom-ref":"r2","name":"zlib","version":"1.3.1"}],"dependencies":[]}'
RT_EMPTY='{"bomFormat":"CycloneDX",'$(meta runtime_only)',"components":[],"dependencies":[]}'
RT_NOT_CDX='{"spdxVersion":"SPDX-2.3","components":[{"bom-ref":"r1","name":"openssl"}]}'

run() {
  rm -rf "$TMP/out"
  STUB_RUNTIME="$1" STUB_BUILDTIME="${2:-$BT_GOOD}" \
    SBOM_VERSION=9.9.9 SBOM_TARGET="${3:-$ROOT#toplevel}" \
    bash "$SCRIPT" --out-dir "$TMP/out" >"$TMP/log" 2>&1
}

RT_OUT="$TMP/out/annixion-9.9.9.cdx.json"
BT_OUT="$TMP/out/annixion-9.9.9.buildtime.cdx.json"
PAGE_OUT="$TMP/out/annixion-9.9.9.supply-chain.md"

# ── The names the release assets carry ───────────────────────────────
mapfile -t names < <(SBOM_VERSION=1.2.3 bash "$SCRIPT" --name 2>/dev/null)
report "$([ "${#names[@]}" -eq 3 ] && echo 0 || echo 1)" \
  "--name lists all three assets" "got ${#names[@]}: ${names[*]-}"
report "$([ "${names[0]:-}" = "annixion-1.2.3.cdx.json" ] && echo 0 || echo 1)" \
  "the runtime SBOM is the version-stamped asset" "got \"${names[0]:-}\""
report "$([ "${names[1]:-}" = "annixion-1.2.3.buildtime.cdx.json" ] && echo 0 || echo 1)" \
  "the buildtime SBOM is named apart from it" "got \"${names[1]:-}\""
report "$([ "${names[2]:-}" = "annixion-1.2.3.supply-chain.md" ] && echo 0 || echo 1)" \
  "the readable page is named alongside them" "got \"${names[2]:-}\""

# VERSION is what CI stamps releases with; the assets have to agree with it or
# they do not match the tag they ship under.
name=$(bash "$SCRIPT" --name 2>/dev/null | head -1)
report "$([ "$name" = "annixion-$(tr -d '\r\n' <"$ROOT/VERSION").cdx.json" ] && echo 0 || echo 1)" \
  "--name reads VERSION" "got \"$name\""

# ── Store path vs flakeref ───────────────────────────────────────────
run "$RT_GOOD" "$BT_GOOD" "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-nixos-system"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a store path is refused" "scanned it anyway, so the SBOMs would ship without licences"

# ── The happy path ───────────────────────────────────────────────────
mkdir -p "$TMP/cwd"
rm -rf "$TMP/out"
STUB_RUNTIME="$RT_GOOD" STUB_BUILDTIME="$BT_GOOD" SBOM_VERSION=9.9.9 \
  SBOM_TARGET="$ROOT#toplevel" \
  bash -c 'cd "$1" && bash "$2" --out-dir "$3"' _ "$TMP/cwd" "$SCRIPT" "$TMP/out" >"$TMP/log" 2>&1
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "a well-formed pair is accepted" "$(tail -1 "$TMP/log")"
report "$([ -f "$RT_OUT" ] && echo 0 || echo 1)" "the runtime SBOM lands in --out-dir" "missing $RT_OUT"
report "$([ -f "$BT_OUT" ] && echo 0 || echo 1)" "the buildtime SBOM lands beside it" "missing $BT_OUT"
report "$([ -s "$PAGE_OUT" ] && echo 0 || echo 1)" "the readable page is rendered" "missing or empty $PAGE_OUT"

# The whole point of naming every output path and scanning from a scratch
# directory: a contributor running this by hand gets no untracked files.
strays=$(find "$TMP/cwd" -mindepth 1 -printf '%P ' 2>/dev/null)
report "$([ -z "$strays" ] && echo 0 || echo 1)" \
  "nothing is written to the working directory" "left behind: $strays"

# ── Metrics, recomputed rather than quoted ───────────────────────────
# A figure copied from a previous release is wrong the moment the closure moves,
# and wrong in a way nobody notices, so both documents carry their own.
for f in "$RT_OUT" "$BT_OUT"; do
  label=$(basename "$f")
  got=$(jq -r '(.metadata.properties // [])
    | map(select(.name == "annixion:closure_store_paths")) | (.[0].value // "")' "$f" 2>/dev/null)
  report "$([ "$got" = "3" ] && echo 0 || echo 1)" \
    "$label carries the store-path count" "got \"$got\", expected the 3 paths nix reported"
  got=$(jq -r '(.metadata.properties // [])
    | map(select(.name == "annixion:closure_size")) | (.[0].value // "")' "$f" 2>/dev/null)
  report "$([ "$got" = "23.37 GiB" ] && echo 0 || echo 1)" \
    "$label carries the closure size" "got \"$got\", expected 23.37 GiB from 25097156362 bytes"
done
report "$(grep -q '3 store paths, 23.37 GiB' "$PAGE_OUT" && echo 0 || echo 1)" \
  "the page reports the same figures" "the page and the SBOMs disagree"

# ── The failures that are otherwise silent ───────────────────────────
run "$RT_NO_LICENCE"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a runtime SBOM with no licence data is refused" "accepted sbomnix's minimum attribute set"

run "$RT_EMPTY"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "an SBOM with no components is refused" "accepted an empty component list"

run "$RT_NOT_CDX"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a non-CycloneDX document is refused" "accepted a document that is not CycloneDX"

# The build closure must contain the runtime one — the page's "does not ship"
# half is a set difference, and if the sets stop nesting it silently lies.
run "$RT_GOOD" "$BT_NOT_SUPERSET"
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a build closure missing a runtime package is refused" "the two SBOMs no longer nest and it shipped anyway"

# The mirror of that: the licence floor is a runtime-only rule. Holding the
# build closure to it would fail every release, since most of it is bootstrap
# plumbing, tarballs and patches that carry no licence at all.
run "$RT_GOOD" "$BT_NO_LICENCE"
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "an unlicensed build closure is still accepted" "$(tail -1 "$TMP/log")"

# ── The wiring, which cannot be tried locally ────────────────────────
# The SBOMs are generated in `check` because that job already builds the closure
# and separate jobs share no store; `iso` can only publish what it downloads.
steps() { yq -r ".jobs.$1.steps[] | (.name // \"\") + \" \" + (.uses // \"\") + \" \" + (.run // \"\")" "$WORKFLOW" 2>/dev/null; }
check_steps=$(steps check)
iso_steps=$(steps iso)
lint_steps=$(steps lint)

report "$(grep -q 'generate-sbom.sh' <<<"$check_steps" && echo 0 || echo 1)" \
  "the check job generates the SBOMs" "no step runs generate-sbom.sh"
report "$(grep -q 'upload-artifact' <<<"$check_steps" && echo 0 || echo 1)" \
  "the check job uploads them" "nothing hands the SBOMs to the iso job"
report "$(grep -q 'download-artifact' <<<"$iso_steps" && echo 0 || echo 1)" \
  "the iso job downloads them" "the release job never receives the SBOMs"
report "$(grep -q 'out-link result-toplevel' <<<"$check_steps" && echo 0 || echo 1)" \
  "the closure build keeps an out-link" "L2 still builds with --no-link, and the metrics read the live store"

# Every asset the generator names has to reach the release, or an operator
# follows a release note to a file that is not there.
for asset in SBOM_PATH BUILDTIME_PATH PAGE_PATH; do
  report "$(grep -q "$asset" <<<"$iso_steps" && echo 0 || echo 1)" \
    "the release publishes \$$asset" "gh release create does not list it"
done
report "$(grep -q 'SHA256SUMS' <<<"$iso_steps" && echo 0 || echo 1)" \
  "a checksum covers the release assets" "no SHA256SUMS in the release job"

# Both fixture tests have to actually run in CI.
for t in sbom supply-chain; do
  report "$(grep -q "tests/repo/$t.sh" <<<"$lint_steps" && echo 0 || echo 1)" \
    "tests/repo/$t.sh runs in CI" "not wired into the L0 script tests step"
done

echo
if [ "$fails" -gt 0 ]; then
  printf 'sbom: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "sbom: both SBOMs are generated, validated, measured and published"
