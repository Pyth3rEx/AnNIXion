#!/usr/bin/env bash
# The published security pages are read by people deciding whether to trust a
# release, so the failures that matter are failures of framing. A finding filed
# in the wrong bucket says a fix exists when it does not. A finding dropped
# because one scanner saw it removes the worst thing on the page. A maintainer
# hidden behind "+3" cannot be contacted, which is the only reason the column is
# there. A local helper counted as an unmaintained dependency inflates a number
# we publish about ourselves, in our favour.
#
# Drives the real renderer against handmade vulnxscan CSVs and metadata.
# Nearly every pattern here is markdown, and markdown is made of backticks.
# shellcheck disable=SC2016
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/scripts/render-security-pages.py"
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

# One finding per classification, one label the tool does not document, one
# scored low and one not scored at all.
cat >"$TMP/triage.csv" <<'CSV'
"vuln_id","url","package","severity","version_local","version_nixpkgs","version_upstream","package_repology","sortcol","classify"
"CVE-2026-1000","https://nvd.nist.gov/vuln/detail/CVE-2026-1000","nghttp2","6.3","1.69.0","1.70.0","1.71.0","nghttp2","1","fix_update_to_version_nixpkgs"
"CVE-2026-2000","https://nvd.nist.gov/vuln/detail/CVE-2026-2000","xrdp","9.8","0.10.6","0.10.6","0.10.6.1","xrdp","1","fix_update_to_version_upstream"
"CVE-2026-3000","https://nvd.nist.gov/vuln/detail/CVE-2026-3000","libssh2","8.7","1.11.1","1.11.1","1.11.1","libssh2","1","fix_not_available"
"CVE-2026-4000","https://nvd.nist.gov/vuln/detail/CVE-2026-4000","openssl","7.5","3.6.3","4.0.2","4.0.2","openssl","1","err_not_vulnerable_based_on_repology"
"CVE-2026-5000","https://nvd.nist.gov/vuln/detail/CVE-2026-5000","weirdpkg","5.0","1.0","","","","1","err_missing_repology_version"
"CVE-2026-6000","https://nvd.nist.gov/vuln/detail/CVE-2026-6000","openssl","9.9","3.6.3","4.0.2","4.0.2","openssl","1","err_not_vulnerable_based_on_repology"
"CVE-2026-7000","https://nvd.nist.gov/vuln/detail/CVE-2026-7000","libssh2","2.1","1.11.1","1.11.1","1.11.1","libssh2","1","fix_not_available"
"CVE-2026-8000","https://nvd.nist.gov/vuln/detail/CVE-2026-8000","libssh2","","1.11.1","1.11.1","1.11.1","libssh2","1","fix_not_available"
CSV

# xrdp is the single-engine case: vulnix alone, grype blind to it.
cat >"$TMP/vulns.csv" <<'CSV'
"vuln_id","url","package","version_local","severity","vulnix","grype","osv","sum","sortcol"
"CVE-2026-1000","https://nvd.nist.gov/vuln/detail/CVE-2026-1000","nghttp2","1.69.0","6.3","0","1","1","2","1"
"CVE-2026-2000","https://nvd.nist.gov/vuln/detail/CVE-2026-2000","xrdp","0.10.6","9.8","1","0","0","1","1"
"CVE-2026-3000","https://nvd.nist.gov/vuln/detail/CVE-2026-3000","libssh2","1.11.1","8.7","0","1","0","1","1"
"CVE-2026-4000","https://nvd.nist.gov/vuln/detail/CVE-2026-4000","openssl","3.6.3","7.5","0","1","0","1","1"
"CVE-2026-5000","https://nvd.nist.gov/vuln/detail/CVE-2026-5000","weirdpkg","1.0","5.0","0","0","1","1","1"
"CVE-2026-6000","https://nvd.nist.gov/vuln/detail/CVE-2026-6000","openssl","3.6.3","9.9","0","1","0","1","1"
"CVE-2026-7000","https://nvd.nist.gov/vuln/detail/CVE-2026-7000","libssh2","1.11.1","2.1","0","1","0","1","1"
"CVE-2026-8000","https://nvd.nist.gov/vuln/detail/CVE-2026-8000","libssh2","1.11.1","","0","1","0","1","1"
CSV

# openssl carries four maintainers, so "all of them" is checkable; weirdpkg does
# not resolve to a nixpkgs attribute at all.
cat >"$TMP/prov.json" <<'JSON'
{
  "nghttp2": { "license": "MIT License", "maintainers": [] },
  "xrdp": { "license": "Apache License 2.0", "maintainers": [
    { "name": "Charlotte", "github": "chvp" }, { "name": "Lucas", "github": "lucasew" } ] },
  "libssh2": { "license": "BSD 3-clause \"New\" or \"Revised\" License", "maintainers": [] },
  "openssl": { "license": "Apache License 2.0", "maintainers": [
    { "name": "A", "github": "aaa" }, { "name": "B", "github": "bbb" },
    { "name": "C", "github": "ccc" }, { "name": "D", "github": "ddd" } ] },
  "weirdpkg": null
}
JSON

# xrdp is upstream and maintained, cowsay upstream and orphaned, annixion-thing
# defined here. The third must not be counted as an orphan.
cat >"$TMP/apps.json" <<'JSON'
[
  { "name": "xrdp", "version": "0.10.6", "description": "RDP server",
    "license": "Apache License 2.0", "homepage": "https://example.invalid/xrdp",
    "position": "/nix/store/hhh-source/pkgs/by-name/xr/xrdp/package.nix:12",
    "maintainers": [ { "name": "Charlotte", "github": "chvp" } ] },
  { "name": "cowsay", "version": "3.8.4", "description": "Talking cow",
    "license": "GPL-3.0", "homepage": "",
    "position": "/nix/store/hhh-source/pkgs/by-name/co/cowsay/package.nix:40",
    "maintainers": [] },
  { "name": "annixion-thing", "version": "", "description": "",
    "license": "", "homepage": "",
    "position": "/nix/store/ggg-source/system/security-tools.nix:21",
    "maintainers": [] }
]
JSON

cat >"$TMP/sbom.json" <<'JSON'
{
  "bomFormat": "CycloneDX",
  "metadata": { "timestamp": "2026-01-01T00:00:00+00:00", "properties": [
    { "name": "annixion:closure_store_paths", "value": "2616" },
    { "name": "annixion:closure_size", "value": "23.37 GiB" } ] },
  "components": [
    { "bom-ref": "a", "name": "openssl", "version": "3.6.3" },
    { "bom-ref": "b", "name": "libssh2", "version": "1.11.1" },
    { "bom-ref": "c", "name": "zlib", "version": "1.3.1" },
    { "bom-ref": "d", "name": "fix-rpath.patch", "version": "" }
  ]
}
JSON

OUT="$TMP/out"
render() {
  rm -rf "$OUT"
  python3 "$SCRIPT" --triage "$TMP/triage.csv" --vulns "$TMP/vulns.csv" \
    --provenance "$TMP/prov.json" --apps "$TMP/apps.json" --sbom "$TMP/sbom.json" \
    --out-dir "$OUT" --version 1.2.3 --generated "2026-01-01 00:00 UTC" "$@"
}

render --coverage full >"$TMP/log" 2>"$TMP/err"
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "the pages render" "$(tail -1 "$TMP/err")"

INDEX="$OUT/README.md" CVES="$OUT/cves.md" PKGS="$OUT/packages.md" APPS="$OUT/apps.md"

# ── Four pages, and the index links to each ──────────────────────────
for f in README.md cves.md packages.md apps.md; do
  report "$([ -s "$OUT/$f" ] && echo 0 || echo 1)" "$f is written" "missing or empty"
done
for target in "cves.md" "packages.md" "apps.md"; do
  report "$(grep -q "($target)" "$INDEX" && echo 0 || echo 1)" \
    "the index links to $target" "no link to $target"
done
report "$(grep -q '(README.md)' "$CVES" && grep -q '(README.md)' "$PKGS" && grep -q '(README.md)' "$APPS" && echo 0 || echo 1)" \
  "every page links back to the index" "a page is a dead end"

# ── Nothing is dropped between CSV and page ──────────────────────────
report "$(grep -q '8 findings' "$INDEX" && echo 0 || echo 1)" \
  "the index counts every finding" "$(grep -o '[0-9]* findings[^|]*' "$INDEX" | head -1)"
report "$(grep -q '^| Total | 2 | 2 | 2 | 1 | 1 | 8 |$' "$INDEX" && echo 0 || echo 1)" \
  "the severity cross-tab totals every finding" "$(grep '^| Total' "$INDEX")"
report "$(grep -q '^## Unclassified (1)' "$CVES" && grep -q 'CVE-2026-5000' "$CVES" && echo 0 || echo 1)" \
  "an unrecognised triage label is kept, not dropped" "err_missing_repology_version vanished"

# ── Buckets ──────────────────────────────────────────────────────────
report "$(grep -q '^## Fix in nixpkgs (1)' "$CVES" && echo 0 || echo 1)" "the nixpkgs bucket is counted" "wrong count"
report "$(grep -q '^## Fixed upstream (1)' "$CVES" && echo 0 || echo 1)" "the upstream bucket is counted" "wrong count"
report "$(grep -q '^## No fix (3)' "$CVES" && echo 0 || echo 1)" "the no-fix bucket is counted" "wrong count"
report "$(grep -q '<strong>Not applicable (2)</strong>' "$CVES" && echo 0 || echo 1)" \
  "not-applicable is folded, not deleted" "the fold is missing"

# An upstream-only finding must not advertise the nixpkgs version as its fix.
report "$(grep -qE 'CVE-2026-2000.*`0\.10\.6` \| `0\.10\.6\.1`' "$CVES" && echo 0 || echo 1)" \
  "an upstream-only fix shows the upstream version" "$(grep -o 'CVE-2026-2000.*' "$CVES" | head -c 130)"

# ── Severity grades ──────────────────────────────────────────────────
report "$(grep -qE 'CVE-2026-2000.*\| 🔴 9\.8 \|' "$CVES" && echo 0 || echo 1)" "critical grades red" "no red 9.8"
report "$(grep -qE 'CVE-2026-3000.*\| 🟠 8\.7 \|' "$CVES" && echo 0 || echo 1)" "high grades orange" "no orange 8.7"
report "$(grep -qE 'CVE-2026-1000.*\| 🟡 6\.3 \|' "$CVES" && echo 0 || echo 1)" "medium grades yellow" "no yellow 6.3"
report "$(grep -qE 'CVE-2026-7000.*\| 🟢 2\.1 \|' "$CVES" && echo 0 || echo 1)" "low grades green" "no green 2.1"
report "$(grep -qE 'CVE-2026-8000.*\| ⚪ — \|' "$CVES" && echo 0 || echo 1)" \
  "an unscored finding is ungraded, not low" "$(grep -o 'CVE-2026-8000.*' "$CVES" | head -c 80)"

# ── The single-engine finding a vote filter would delete ─────────────
report "$(grep -q 'CVE-2026-2000' "$CVES" && echo 0 || echo 1)" \
  "a finding only one engine saw is kept" "the sum=1 finding was filtered out"
report "$(grep -qE 'CVE-2026-2000.*\| vulnix \|' "$CVES" && echo 0 || echo 1)" \
  "the page names the engine that saw it" "$(grep -o 'CVE-2026-2000.*' "$CVES" | head -c 130)"

# ── Every maintainer reachable ───────────────────────────────────────
# A "+2" is not a contact. All four of openssl's have to be clickable.
for h in aaa bbb ccc ddd; do
  report "$(grep -q "\[@$h\](https://github.com/$h)" "$CVES" && echo 0 || echo 1)" \
    "maintainer @$h is linked" "@$h is hidden behind a count"
done
report "$(grep -qE '\+[0-9]' "$CVES" "$APPS" "$PKGS" && echo 1 || echo 0)" \
  "no maintainer list is truncated" "a page still abbreviates a maintainer list"
report "$(grep -qE 'CVE-2026-1000.*\| \*\*none\*\* \|' "$CVES" && echo 0 || echo 1)" \
  "a package with no maintainer says none" "$(grep -o 'CVE-2026-1000.*' "$CVES" | head -c 130)"
report "$(grep -q '\*unresolved\*' "$CVES" && echo 0 || echo 1)" \
  "a package that does not resolve is marked unresolved" "weirdpkg reads as maintained or orphaned"

# ── Licences named ───────────────────────────────────────────────────
report "$(grep -q 'Apache License 2.0' "$CVES" && echo 0 || echo 1)" \
  "licences are named, not SPDX ids" "no spelled-out licence"
report "$(grep -q 'Licence' "$PKGS" && grep -q 'Licence' "$APPS" && echo 0 || echo 1)" \
  "packages and apps both carry a licence column" "a page omits licences"

# ── Apps: origin, and who is actually orphaned ───────────────────────
report "$(grep -qE '^\| \[`cowsay`' "$APPS" || grep -q '`cowsay`' "$APPS" && echo 0 || echo 1)" \
  "a declared app is listed" "cowsay is missing"
report "$(grep -qE '`annixion-thing`.*\*this repo\*' "$APPS" && echo 0 || echo 1)" \
  "an app defined here is attributed to this repo" "$(grep -o 'annixion-thing.*' "$APPS" | head -c 130)"
report "$(grep -qE '`cowsay`.*\*\*none\*\*' "$APPS" && echo 0 || echo 1)" \
  "an orphaned nixpkgs app says none" "$(grep -o '`cowsay`.*' "$APPS" | head -c 130)"
report "$(grep -q 'github.com/NixOS/nixpkgs/blob/' "$APPS" && echo 0 || echo 1)" \
  "an upstream app links to where nixpkgs defines it" "no nixpkgs source link"

# The count we publish about ourselves: one orphan out of two upstream apps,
# with the local helper counted separately rather than padding the number.
report "$(grep -q '| nixpkgs applications with no maintainer | 1 / 2 |' "$INDEX" && echo 0 || echo 1)" \
  "local packages are not counted as orphans" "$(grep 'no maintainer' "$INDEX" | head -1)"
report "$(grep -q '| Applications defined in this repo | 1 |' "$INDEX" && echo 0 || echo 1)" \
  "and are counted on their own line" "$(grep 'this repo' "$INDEX" | head -1)"

# ── Packages page ────────────────────────────────────────────────────
report "$(grep -q '| `zlib` | `1.3.1` |' "$PKGS" && echo 0 || echo 1)" \
  "a transitive package with no findings is still listed" "zlib is missing"
report "$(grep -q 'fix-rpath.patch' "$PKGS" && echo 1 || echo 0)" \
  "a patch is not listed as a package" "a .patch appears in the package list"
report "$(grep -qE '^\| `openssl` \| `3\.6\.3` \|.*\| 2 \| *\|$' "$PKGS" && echo 0 || echo 1)" \
  "findings are counted per package" "$(grep -o '^| `openssl`.*' "$PKGS" | head -c 160)"
report "$(grep -q '2616 store paths' "$PKGS" && echo 0 || echo 1)" \
  "the closure metrics carry onto the packages page" "no store-path count"

# ── Coverage tiers ───────────────────────────────────────────────────
report "$(grep -q 'vulnix' "$INDEX" && echo 0 || echo 1)" "the index states engine coverage" "no engine caveat"
render --coverage reduced >/dev/null 2>&1
report "$(grep -q 'vulnix. did not run' "$OUT/README.md" && echo 0 || echo 1)" \
  "an SBOM-only scan says vulnix did not run" "no reduced-coverage warning"

echo
if [ "$fails" -gt 0 ]; then
  printf 'security-pages: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "security-pages: four pages, every finding kept and every maintainer reachable"
