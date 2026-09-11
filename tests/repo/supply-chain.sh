#!/usr/bin/env bash
# The supply-chain page exists to keep two things apart that a scanner would
# happily merge: what is installed, and what merely built it. If the page ever
# lets a build-only compiler drift into part 1, it stops being a document that
# calms a reader down about a gcc CVE and becomes one that alarms them — which
# is the failure mode the whole split exists to prevent. These drive the real
# renderer against handmade SBOMs, so every classification is checkable.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/scripts/render-supply-chain.sh"
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

# openssl ships and is also a build input; zlib only ships.
cat >"$TMP/rt.json" <<'JSON'
{
  "bomFormat": "CycloneDX",
  "metadata": {
    "timestamp": "2026-01-01T00:00:00+00:00",
    "properties": [
      { "name": "sbom_type", "value": "runtime_only" },
      { "name": "annixion:version", "value": "1.2.3" },
      { "name": "annixion:closure_store_path", "value": "/nix/store/xxx-nixos-system" },
      { "name": "annixion:closure_store_paths", "value": "2616" },
      { "name": "annixion:closure_size", "value": "23.37 GiB" }
    ]
  },
  "components": [
    { "bom-ref": "r-openssl", "name": "openssl", "version": "3.5.0",
      "licenses": [ { "license": { "id": "Apache-2.0" } } ] },
    { "bom-ref": "r-zlib", "name": "zlib", "version": "1.3.1" },
    { "bom-ref": "r-src", "name": "openssl-3.5.0.tar.gz" }
  ],
  "dependencies": [ { "ref": "r-openssl", "dependsOn": [ "r-zlib" ] } ]
}
JSON

# The build closure is a superset: the two runtime packages plus a compiler, a
# fetched archive and a patch that never reach the installed system.
cat >"$TMP/bt.json" <<'JSON'
{
  "bomFormat": "CycloneDX",
  "metadata": {
    "timestamp": "2026-01-01T00:00:00+00:00",
    "properties": [ { "name": "sbom_type", "value": "runtime_and_buildtime" } ]
  },
  "components": [
    { "bom-ref": "r-openssl", "name": "openssl", "version": "3.5.0",
      "licenses": [ { "license": { "id": "Apache-2.0" } } ] },
    { "bom-ref": "r-zlib", "name": "zlib", "version": "1.3.1" },
    { "bom-ref": "r-src", "name": "openssl-3.5.0.tar.gz" },
    { "bom-ref": "b-gcc", "name": "gcc", "version": "15.2.0",
      "licenses": [ { "license": { "id": "GPL-3.0-or-later" } } ] },
    { "bom-ref": "b-tar", "name": "some-dep-2.0.tar.xz" },
    { "bom-ref": "b-patch", "name": "fix-rpath.patch" },
    { "bom-ref": "b-builder", "name": "builder.sh" }
  ],
  "dependencies": [
    { "ref": "r-openssl", "dependsOn": [ "r-zlib", "b-gcc", "b-patch" ] },
    { "ref": "r-zlib",    "dependsOn": [ "b-gcc", "b-tar" ] },
    { "ref": "b-gcc",     "dependsOn": [ "b-builder" ] },
    { "ref": "b-tar",     "dependsOn": null }
  ]
}
JSON

PAGE="$TMP/page.md"
bash "$SCRIPT" --runtime "$TMP/rt.json" --buildtime "$TMP/bt.json" >"$PAGE" 2>"$TMP/err"
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "the page renders" "$(tail -1 "$TMP/err")"

# Sections of the page, so a claim about part 1 cannot be satisfied by a line
# that is actually in part 2.
awk '/^## Part 2/{exit} {print}' "$PAGE" >"$TMP/part1"
awk '/^## Part 2/{p=1} p' "$PAGE" >"$TMP/part2"

# ── The split ────────────────────────────────────────────────────────
report "$(grep -q '^| openssl | 3.5.0 | Apache-2.0 |$' "$TMP/part1" && echo 0 || echo 1)" \
  "an installed package is in part 1, with its licence" "openssl row missing or malformed"

report "$(grep -q '^| gcc |' "$TMP/part1" && echo 1 || echo 0)" \
  "a build-only compiler is NOT in part 1" "gcc appears in the installed half"

report "$(grep -q '^| gcc | 15.2.0 |' "$TMP/part2" && echo 0 || echo 1)" \
  "the build-only compiler is in part 2" "gcc missing from the build-only list"

# A fetched tarball is not a package on the system; it appeared in part 1 until
# it was filtered, which quietly overstated what is installed.
report "$(grep -q 'openssl-3.5.0.tar.gz' "$TMP/part1" && echo 1 || echo 0)" \
  "a fetched archive is not listed as installed" "a .tar.gz is in the installed half"

# ── Classification ───────────────────────────────────────────────────
report "$(grep -q 'some-dep-2.0.tar.xz' "$TMP/part2" && echo 0 || echo 1)" \
  "a fetched archive is listed under sources" "some-dep-2.0.tar.xz missing from part 2"
report "$(grep -q 'fix-rpath.patch' "$TMP/part2" && echo 0 || echo 1)" \
  "a patch is listed" "fix-rpath.patch missing from part 2"
report "$(grep -q '1 packages, 1 source archives, 1 patches, 1 build steps' "$PAGE" && echo 0 || echo 1)" \
  "the build-only tallies split by kind" "got: $(grep -o '[0-9]* packages, .*' "$PAGE" | head -1)"

# ── Reach, and whether an input also ships ───────────────────────────
# gcc feeds two builds and ships nothing; zlib feeds one and is installed.
report "$(grep -qE '^\| gcc 15\.2\.0 \| 2 \| no \|$' "$TMP/part2" && echo 0 || echo 1)" \
  "reach counts the builds an input feeds" "$(grep -E '^\| gcc' "$TMP/part2" | head -1)"
report "$(grep -qE '^\| zlib 1\.3\.1 \| 1 \| yes \|$' "$TMP/part2" && echo 0 || echo 1)" \
  "an input that also ships is marked as such" "$(grep -E '^\| zlib' "$TMP/part2" | head -1)"

# ── The metrics carried through from the SBOM ────────────────────────
report "$(grep -q '2616 store paths, 23.37 GiB' "$PAGE" && echo 0 || echo 1)" \
  "the closure metrics are read off the SBOM" "no store-path/size line on the page"
report "$(grep -q 'AnNIXion 1.2.3 — supply chain' "$PAGE" && echo 0 || echo 1)" \
  "the page is stamped with the release version" "no version in the title"

# ── The framing, which is the point of the document ──────────────────
# Without this the page is just two lists, and a reader has no reason not to
# add them together.
report "$(grep -qi 'never added together' "$PAGE" && echo 0 || echo 1)" \
  "the page says the halves are not to be summed" "the framing sentence is gone"
report "$(grep -qi 'Nothing in this part is installed' "$TMP/part2" && echo 0 || echo 1)" \
  "part 2 opens by saying none of it ships" "the part 2 disclaimer is gone"

# ── A null dependsOn must not take the renderer down ─────────────────
# sbomnix emits these: 146 of 1219 entries on a real scan.
report "$([ -s "$PAGE" ] && ! grep -qi 'jq: error' "$TMP/err" && echo 0 || echo 1)" \
  "a null dependsOn is tolerated" "$(grep -i 'jq: error' "$TMP/err" | head -1)"

# ── Refusals ─────────────────────────────────────────────────────────
if bash "$SCRIPT" --runtime "$TMP/rt.json" >/dev/null 2>&1; then rc=0; else rc=1; fi
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a missing --buildtime is refused" "rendered a page with only half its input"

if bash "$SCRIPT" --runtime "$TMP/nope.json" --buildtime "$TMP/bt.json" >/dev/null 2>&1; then rc=0; else rc=1; fi
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "an unreadable SBOM is refused" "carried on without the runtime half"

echo
if [ "$fails" -gt 0 ]; then
  printf 'supply-chain: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "supply-chain: installed and build-only stay apart, and the page says why"
