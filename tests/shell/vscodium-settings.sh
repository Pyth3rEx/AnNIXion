#!/usr/bin/env bash
# Editor settings that only misbehave on this deployment. Hyper-V Enhanced
# Session reports scan codes the editor cannot trust, so dispatching on them
# turns AltGr into a bare cursor-left and AZERTY loses its third level (#163,
# microsoft/vscode#24783). Nothing in the editor surfaces the setting, and a
# profile rename or an upstream default flip would drop it silently.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYS='.#nixosConfigurations.AnNIXion-ci.config'
HM="$SYS.home-manager.users.operator"
SETTINGS="$HM.programs.vscodium.profiles.default.userSettings"
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

# ── Keyboard dispatch ──────────────────────────────────────────────────────
dispatch=$(nix eval --raw "$SETTINGS.\"keyboard.dispatch\"" 2>/dev/null)
report "$([ "$dispatch" = "keyCode" ] && echo 0 || echo 1)" \
  "keybindings dispatch on the layout, not scan codes" \
  "keyboard.dispatch is ${dispatch:-<unset>}"

# ── Hidden files in the explorer ───────────────────────────────────────────
# Unsetting this is not the same as emptying it: with no value the editor
# falls back to a default list that hides .git, which is what #162 reported.
excluded=$(nix eval --json "$SETTINGS.\"files.exclude\"" 2>/dev/null)
report "$([ "$excluded" = "{}" ] && echo 0 || echo 1)" \
  "the explorer hides nothing" \
  "files.exclude is ${excluded:-<unset>}"

echo
if [ "$fails" -gt 0 ]; then
  printf 'vscodium-settings: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'vscodium-settings: all checks passed\n'
