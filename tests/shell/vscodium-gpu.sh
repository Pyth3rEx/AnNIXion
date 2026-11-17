#!/usr/bin/env bash
# This guest has no DRM render node, so Chromium falls back to SwiftShader's
# software GL: eight rasterizer threads, 83% of the editor's entire CPU time,
# 150-300% of a core whenever anything renders (#166). Nothing reports it —
# the GPU process inherits the zygote's command line, so even `ps` calls it
# "codium --type=zygote". The flag that avoids it lives in a wrapper, which is
# exactly the kind of thing that survives a package bump and silently stops
# being applied.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYS='.#nixosConfigurations.AnNIXion-ci.config'
HM="$SYS.home-manager.users.operator"
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

# ── The launcher the desktop runs ──────────────────────────────────────────
# Built, not read out of the expression: commandLineArgs is a wrapper flag,
# and whether it reaches bin/codium is a property of the built package.
err=$(mktemp)
pkg=$(nix build --no-link --print-out-paths "$HM.programs.vscodium.package" 2>"$err")
detail=$(tail -n 3 "$err" | tr '\n' ' ')
rm -f "$err"

if [ -z "$pkg" ]; then
  report 1 "the editor builds" "${detail:-vscodium did not build}"
else
  bin="$pkg/bin/codium"
  report "$([ -x "$bin" ] && echo 0 || echo 1)" \
    "the editor ships bin/codium" "missing $bin"

  # The exec line specifically. A match anywhere in the file would also be
  # satisfied by the flag appearing in an exported variable, which no
  # Chromium process ever reads.
  execline=$(grep -h '^exec ' "$bin" 2>/dev/null | tail -1)
  case $execline in
    *--disable-gpu*) ok=0 ;;
    *) ok=1 ;;
  esac
  report "$ok" "the launcher passes --disable-gpu" \
    "exec line is ${execline:-<none>}"

  # After the flag, so "codium file.nix" still opens the file rather than
  # having it eaten as an argument to the flag.
  case $execline in
    *--disable-gpu*'"$@"'*) ok=0 ;;
    *) ok=1 ;;
  esac
  report "$ok" "arguments still reach the editor" \
    "\"\$@\" does not follow the flag: ${execline:-<none>}"

  # Every .desktop in the package execs the bare name, so the wrapper is what
  # the panel, the menu and xdg-open all start. A store path here would skip
  # it — that is how a desktop entry ends up on the SwiftShader path while the
  # terminal command is fine.
  bypass=""
  while IFS= read -r line; do
    case ${line#Exec=} in
      codium*) ;;
      *) bypass="$bypass ${line#Exec=}" ;;
    esac
  done < <(grep -h '^Exec=' "$pkg"/share/applications/*.desktop 2>/dev/null)
  report "$([ -z "$bypass" ] && echo 0 || echo 1)" \
    "every desktop entry goes through the wrapper" "bypassed by:$bypass"
fi

# ── The launch paths the repository owns ───────────────────────────────────
# The catalog entry and the Meta+F11 shortcut both have to name the wrapper,
# not a store path, or they run the unwrapped binary with no flag at all.
dump=$(nix build --no-link --print-out-paths .#catalog-json 2>/dev/null)
catalog_exec=$(jq -r '.tools.vscodium.exec' "$dump" 2>/dev/null)
report "$([ "$catalog_exec" = "codium" ] && echo 0 || echo 1)" \
  "the menu entry runs the wrapper" "catalog exec is ${catalog_exec:-<unset>}"

shortcut=$(grep -c 'raise "Meta+F11" "VSCodium" "vscodium" "codium"' \
  home/desktop/plasma/shortcuts.nix)
report "$([ "$shortcut" -eq 1 ] && echo 0 || echo 1)" \
  "the Meta+F11 shortcut runs the wrapper" \
  "shortcuts.nix does not launch the bare 'codium'"

echo
if [ "$fails" -gt 0 ]; then
  printf 'vscodium-gpu: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'vscodium-gpu: all checks passed\n'
