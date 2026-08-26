#!/usr/bin/env bash
# Assertions about the Firefox profiles that only show up in use: which profile
# owns a link, whether the throwaway one forgets, and whether a launcher can
# receive a URL at all. Evaluation only — no build, no VM.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG='.#nixosConfigurations.AnNIXion-ci.config'
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

cd "$ROOT" || exit 1

profiles=$(nix eval --json "$CFG.home-manager.users.operator.programs.firefox.profiles" \
  --apply 'ps: builtins.mapAttrs (n: p: { inherit (p) id isDefault settings; }) ps' 2>/dev/null)
if [ -z "$profiles" ]; then
  echo "firefox-profiles: could not evaluate the profiles"
  exit 1
fi

# ── Exactly one default, and it is the OSINT profile ───────────────────────
defaults=$(jq -r '[to_entries[] | select(.value.isDefault) | .key] | join(",")' <<<"$profiles")
report "$([ "$defaults" = "osint" ] && echo 0 || echo 1)" \
  "osint is the one default profile" "default profiles are: ${defaults:-<none>}"

handler=$(nix eval --raw "$CFG.xdg.mime.defaultApplications.\"x-scheme-handler/https\"" 2>/dev/null)
report "$([ "$handler" = "firefox-osint.desktop" ] && echo 0 || echo 1)" \
  "https links open in osint" "handler is ${handler:-<unset>}"

# ── The unsafe browser keeps nothing ───────────────────────────────────────
# autostart is the one that matters: it holds history, cookies and cache in
# memory. The rest stop a session or a blank page bringing the last one back.
want='{"browser.privatebrowsing.autostart":true,"places.history.enabled":false,
       "browser.cache.disk.enable":false,"browser.startup.page":0,
       "browser.startup.homepage":"about:blank","browser.sessionstore.privacy_level":2,
       "browser.sessionstore.resume_from_crash":false}'
# The entry is bound before use: inside `$got | has(x)` the input to has() is
# $got, so a bare .key there resolves against the settings and comes back null.
wrong=$(jq -er --argjson want "$want" '
  .untrusted.settings as $got
  | [ $want | to_entries[] | . as $e
      | select($got[$e.key] != $e.value)
      | "\($e.key)=\(if ($got | has($e.key)) then ($got[$e.key] | tostring) else "unset" end)"
        + " want \($e.value)" ]
    | join("; ")' <<<"$profiles") || wrong="jq failed to compare the settings"
report "$([ -z "$wrong" ] && echo 0 || echo 1)" \
  "the unsafe browser persists nothing" "$wrong"

# ── A launcher that claims a MIME type must be able to receive a URL ───────
# Without %u/%U the URL is never substituted, Firefox reads the bare argument
# as a path, and the click lands on file:// instead of the site.
missing=""
while read -r entry; do
  body=$(nix eval --raw "$CFG.home-manager.users.operator.home.file.\"$entry\".text" 2>/dev/null)
  grep -q '^MimeType=' <<<"$body" || continue
  grep -qE '^Exec=.*%[uU]' <<<"$body" || missing="$missing $(basename "$entry")"
done < <(nix eval --json "$CFG.home-manager.users.operator.home.file" \
  --apply 'fs: builtins.filter (n: builtins.match ".*firefox.*[.]desktop" n != null) (builtins.attrNames fs)' \
  2>/dev/null | jq -r '.[]')
report "$([ -z "$missing" ] && echo 0 || echo 1)" \
  "every mime-claiming launcher takes a URL" "no %U in$missing"

echo
if [ "$fails" -eq 0 ]; then
  echo "firefox-profiles: all tests passed"
else
  echo "firefox-profiles: $fails test(s) failed"
fi
exit "$fails"
