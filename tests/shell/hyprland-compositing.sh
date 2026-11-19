#!/usr/bin/env bash
# The same gate kwin-compositing.sh checks for KWin, read out the other side:
# annixion.desktop.compositing has to turn Hyprland's blur, shadow and
# animations off on a guest with no render node (#167), and back on wherever
# bare metal has real acceleration to pay for them with.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYS='.#nixosConfigurations.AnNIXion-ci'
HM="$SYS.config.home-manager.users.operator"
CONF='xdg.configFile."hypr/hyprland.conf".text'
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

off=$(nix eval --raw "$HM.$CONF" 2>/dev/null)
offcount=$(grep -cE '^[[:space:]]*enabled=false$' <<<"$off")
report "$([ "$offcount" -eq 3 ] && echo 0 || echo 1)" \
  "blur, shadow and animations are off by default" \
  "found $offcount 'enabled=false' lines, expected 3 (blur, shadow, animations)"

# ── The gate ───────────────────────────────────────────────────────────────
# The option has to reach hyprland.conf. A hardcoded false would pass every
# check above and leave bare metal with no way to get them back.
on=$(nix eval --raw --apply \
  "sys: (sys.extendModules {
     modules = [ { annixion.desktop.compositing = true; } ];
   }).config.home-manager.users.operator.$CONF" \
  "$SYS" 2>/dev/null)
oncount=$(grep -cE '^[[:space:]]*enabled=true$' <<<"$on")
report "$([ "$oncount" -eq 3 ] && echo 0 || echo 1)" \
  "setting the option turns blur, shadow and animations back on" \
  "with annixion.desktop.compositing = true, found $oncount 'enabled=true' lines, expected 3"

echo
if [ "$fails" -gt 0 ]; then
  printf 'hyprland-compositing: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'hyprland-compositing: all checks passed\n'
