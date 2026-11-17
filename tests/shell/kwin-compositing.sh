#!/usr/bin/env bash
# KWin composites through llvmpipe on a guest with no render node — eight
# software rasterizer threads and about three quarters of a core, continuously,
# on a machine whose point is to run security tooling (#167). The setting is
# gated rather than forced off, so what has to keep working is the gate: the
# shipped default, and that it still answers to the option both ways. KWin 6
# dropped the D-Bus method that allowed a live toggle, so nothing about this
# can be checked from a running desktop — it is read out of the configuration
# the next activation would write, or not at all.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYS='.#nixosConfigurations.AnNIXion-ci'
HM="$SYS.config.home-manager.users.operator"
KWINRC="programs.plasma.configFile.kwinrc"
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

# ── The shipped default ────────────────────────────────────────────────────
opt=$(nix eval "$SYS.config.annixion.desktop.compositing" 2>/dev/null)
report "$([ "$opt" = "false" ] && echo 0 || echo 1)" \
  "compositing is off by default" \
  "annixion.desktop.compositing is ${opt:-<unset>}"

# plasma-manager coerces every entry into a submodule, so the setting itself
# sits under .value.
enabled=$(nix eval "$HM.$KWINRC.Compositing.Enabled.value" 2>/dev/null)
report "$([ "$enabled" = "false" ] && echo 0 || echo 1)" \
  "kwinrc turns the compositor off" \
  "Compositing.Enabled is ${enabled:-<unset>}"

# ── The gate ───────────────────────────────────────────────────────────────
# The option has to reach kwinrc. A hardcoded false would pass every check
# above and leave bare metal with no way to get its compositor back.
on=$(nix eval --apply \
  "sys: (sys.extendModules {
     modules = [ { annixion.desktop.compositing = true; } ];
   }).config.home-manager.users.operator.$KWINRC.Compositing.Enabled.value" \
  "$SYS" 2>/dev/null)
report "$([ "$on" = "true" ] && echo 0 || echo 1)" \
  "setting the option turns the compositor back on" \
  "with annixion.desktop.compositing = true, kwinrc reads ${on:-<unset>}"

# Animation *duration*, which is not where the cost was. It stays set so the
# machine that turns compositing on still gets the quick animations.
speed=$(nix eval "$HM.$KWINRC.Compositing.AnimationSpeed.value" 2>/dev/null)
report "$([ "$speed" = "3" ] && echo 0 || echo 1)" \
  "the animation speed survives" "AnimationSpeed is ${speed:-<unset>}"

# Tiling is what makes a desktop with no compositor pleasant to use, and it is
# the one thing here that would be easy to lose along with the compositor.
krohnkite=$(nix eval "$HM.$KWINRC.Plugins.krohnkiteEnabled.value" 2>/dev/null)
report "$([ "$krohnkite" = "true" ] && echo 0 || echo 1)" \
  "Krohnkite tiling is unaffected" "krohnkiteEnabled is ${krohnkite:-<unset>}"

# ── What activation would actually write ───────────────────────────────────
# The option above is this repository's input. plasma-manager writes kwinrc
# from a generated data.json, and that file is what KWin ends up reading — the
# place a setting silently fails to be carried through.
# Through the flake, like tests/shell/branding.sh and tests/shell/catalog.sh:
# the activation step is a store path inside a string, which a runner with a
# cold store cannot realise on its own.
err=$(mktemp)
activation=$(nix build --no-link --print-out-paths '.#plasma-activation' 2>"$err")
detail=$(tail -n 3 "$err" | tr '\n' ' ')
rm -f "$err"

if [ -z "$activation" ]; then
  report 1 "the plasma activation step builds" \
    "${detail:-plasma-activation did not build}"
else
  # The step runs plasma-config, which feeds data.json to write_config. Both
  # are inputs of the file just built, so they are in the store to be read.
  script=$(grep -o '/nix/store/[a-z0-9]*-plasma-config' "$activation" | head -1)
  data=$(grep -o '/nix/store/[a-z0-9]*-data.json' "$script" 2>/dev/null | head -1)
  value=$(jq -r '.[$f].Compositing.Enabled.value' \
    --arg f "/home/operator/.config/kwinrc" "$data" 2>/dev/null)
  report "$([ "$value" = "false" ] && echo 0 || echo 1)" \
    "the written kwinrc has the compositor off" \
    "data.json carries Compositing.Enabled=${value:-<absent>}"
fi

echo
if [ "$fails" -gt 0 ]; then
  printf 'kwin-compositing: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'kwin-compositing: all checks passed\n'
