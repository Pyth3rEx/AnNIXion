#!/usr/bin/env bash
# package-provenance.sh resolves every flagged name in one shared nix eval, so
# one bad name can take the whole batch down rather than just itself. nixpkgs
# keeps top-level aliases for removed packages that evaluate to a throw rather
# than being absent — pkgs.${n} or null does not save you from that, since the
# throw only fires once something forces the value. A finding naming one of
# those (akonadi-mime, a removed KDE Gear 5 package, as of this nixpkgs pin)
# used to crash provenance for every package in the same run, not just that
# one. This drives the real script against the real flake: no stub can stand
# in for "nixpkgs evaluates this attribute to a throw."
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/scripts/package-provenance.sh"
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

cat >"$TMP/names" <<'NAMES'
openssl
akonadi-mime
does-not-exist-in-nixpkgs-xyz987
NAMES

OUT="$TMP/out.json"
bash "$SCRIPT" --names "$TMP/names" >"$OUT" 2>"$TMP/err"
rc=$?

report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "a batch containing a throwing alias still exits 0" "$(cat "$TMP/err")"

report "$(jq -e '.openssl != null and (.openssl.license | length > 0)' "$OUT" >/dev/null 2>&1 && echo 0 || echo 1)" \
  "a normal package in the same batch still resolves" "$(cat "$OUT")"

report "$(jq -e '.["akonadi-mime"] == null' "$OUT" >/dev/null 2>&1 && echo 0 || echo 1)" \
  "a removed top-level alias resolves to null, not a crash" "$(cat "$OUT")"

report "$(jq -e '.["does-not-exist-in-nixpkgs-xyz987"] == null' "$OUT" >/dev/null 2>&1 && echo 0 || echo 1)" \
  "a name with no nixpkgs attribute at all still resolves to null" "$(cat "$OUT")"

echo
if [ "$fails" -gt 0 ]; then
  printf 'package-provenance: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "package-provenance: one bad name in a batch does not cost the batch"
