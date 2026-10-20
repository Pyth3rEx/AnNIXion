#!/usr/bin/env bash
# Single click selecting rather than opening (#171). plasma-manager takes
# clickItemTo as a word and writes kdeglobals as a boolean, so the two can
# disagree without either looking wrong on its own — and the desktop runs
# FocusFollowsMouse, which makes an accidental open easy to trigger.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HM='.#nixosConfigurations.AnNIXion-ci.config.home-manager.users.operator'
PLASMA="$HM.programs.plasma"
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

click=$(nix eval --raw "$PLASMA.workspace.clickItemTo" 2>/dev/null)
report "$([ "$click" = "select" ] && echo 0 || echo 1)" \
  "a single click selects" "clickItemTo is ${click:-<unset>}"

# The boolean the file managers actually read. "select" has to arrive here as
# false; a mapping change upstream would leave the word above still correct.
single=$(nix eval "$PLASMA.configFile.kdeglobals.KDE.SingleClick.value" 2>/dev/null)
report "$([ "$single" = "false" ] && echo 0 || echo 1)" \
  "kdeglobals turns single-click activation off" \
  "KDE.SingleClick is ${single:-<unset>}"

echo
if [ "$fails" -gt 0 ]; then
  printf 'click-behaviour: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'click-behaviour: all checks passed\n'
