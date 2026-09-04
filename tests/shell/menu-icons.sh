#!/usr/bin/env bash
# Every Icon= the AnNIXion menu writes has to resolve to a real file in the
# icon theme the desktop is actually set to. A name that resolves nowhere does
# not error — Plasma draws a blank placeholder and the menu looks half-built,
# which is how `codium`, `wireshark`, `media-removable` and
# `network-transmit-receive` all survived in the tree.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CFG='.#nixosConfigurations.AnNIXion-ci.config'
HM="$CFG.home-manager.users.operator"
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

home=$(nix eval --raw "$HM.home.homeDirectory" 2>/dev/null)
if [ -z "$home" ]; then
  echo "menu-icons: could not evaluate homeDirectory"
  exit 1
fi

# The theme the desktop actually selects, and the icon tree it selects from.
theme=$(nix eval --raw "$HM.programs.plasma.workspace.iconTheme" 2>/dev/null)
icons=$(nix build --no-link --print-out-paths \
  "$HM.home.file.\"$home/.local/share/icons\".source" 2>/dev/null)

if [ -z "$theme" ] || [ -z "$icons" ]; then
  echo "menu-icons: could not resolve the icon theme or its store path"
  exit 1
fi

report "$([ -d "$icons/$theme" ] && echo 0 || echo 1)" \
  "the selected icon theme exists" "$theme is not a directory under $icons"

# ── Collect every Icon= the menu writes ────────────────────────────────────
# .desktop entries and .directory files both carry one.
# shellcheck disable=SC2016 # a Nix expression: ${n} must reach nix unexpanded
entries=$(nix eval --json "$HM.home.file" --apply '
  f:
  let
    inherit (builtins) attrNames filter concatStringsSep;
    wanted = n:
      builtins.match ".*/(applications/.*\\.desktop|desktop-directories/.*\\.directory)" n != null;
  in
    builtins.listToAttrs (map (n: { name = n; value = f.${n}.text or ""; })
      (filter wanted (attrNames f)))
' 2>/dev/null)

if [ -z "$entries" ]; then
  echo "menu-icons: could not evaluate the menu files"
  exit 1
fi

# ── Resolve each name against the theme and everything it inherits ─────────
# An icon may live in the selected theme, in a theme it inherits, or be an
# absolute path (the Firefox launchers use those).
resolve() {
  local name="$1"
  case "$name" in
    /*) [ -f "$name" ] && return 0 || return 1 ;;
  esac
  find "$icons" -name "$name.svg" -o -name "$name.png" 2>/dev/null | grep -q .
}

missing=""
checked=0
while IFS=$'\t' read -r file icon; do
  [ -z "$icon" ] && continue
  checked=$((checked + 1))
  resolve "$icon" || missing="$missing\n    $(basename "$file") -> $icon"
done < <(jq -r 'to_entries[]
  | .key as $f
  | .value
  | split("\n")[]
  | select(startswith("Icon="))
  | [$f, ltrimstr("Icon=")]
  | @tsv' <<<"$entries")

report "$([ "$checked" -gt 0 ] && echo 0 || echo 1)" \
  "the menu declares icons at all" "no Icon= lines found in any menu file"

report "$([ -z "$missing" ] && echo 0 || echo 1)" \
  "every menu icon resolves in $theme" \
  "$checked checked, these resolve nowhere:$(printf '%b' "$missing")"

# ── No mark may lose ink off the edge of its canvas ────────────────────────
# A round cap reaches half a stroke past the geometry, so a drip that ends on
# the grid edge is sliced flat and reads as a cut rather than a drawn end.
bbox=$(python3 "$ROOT/scripts/mark-bbox.py" "$icons/$theme/scalable/apps" --quiet 2>&1)
report "$?" "no mark loses ink off its canvas" "$bbox"

# ── The panel launcher names a mark too ────────────────────────────────────
# It is not a menu file, so the sweep above never sees it. It used to be an
# absolute path to a PNG, which could not go stale; a theme name can, and a
# launcher whose icon resolves nowhere is a blank square on the panel.
launcher=$(nix eval --raw "$HM.programs.plasma.panels" --apply '
  ps:
  let
    widgets = builtins.concatLists (map (p: p.widgets) ps);
    tiled = builtins.filter (w: (w.name or "") == "com.github.zren.tiledmenu") widgets;
  in
    if tiled == [ ] then "" else (builtins.head tiled).config.General.icon
' 2>/dev/null)

report "$([ -n "$launcher" ] && echo 0 || echo 1)" \
  "the panel launcher declares an icon" "found no tiled menu widget carrying one"

if [ -n "$launcher" ]; then
  report "$(resolve "$launcher" && echo 0 || echo 1)" \
    "the panel launcher icon resolves in $theme" "$launcher resolves nowhere"
fi

# ── Every un-namespaced icon is a deliberate alias ─────────────────────────
# Marks are namespaced so a collision with an upstream icon cannot silently
# win the lookup. The exception is the alias set: an application that ships
# its own .desktop entry asks for the name that entry declares, so the mark
# is installed under it too. Each of those must be a symlink onto a mark that
# exists — a stray regular file is an accidental collision, and a dangling
# link is a mark that was renamed out from under its alias.
aliases=0
broken=""
while IFS= read -r link; do
  aliases=$((aliases + 1))
  target=$(readlink "$link" 2>/dev/null)
  case "$target" in
    annixion-*.svg) [ -f "$icons/$theme/scalable/apps/$target" ] || broken="$broken\n    $(basename "$link") -> ${target} (dangling)" ;;
    "") broken="$broken\n    $(basename "$link") is a regular file, not an alias" ;;
    *) broken="$broken\n    $(basename "$link") -> ${target} (not a mark)" ;;
  esac
done < <(find "$icons/$theme" -name '*.svg' ! -name 'annixion-*' 2>/dev/null)

report "$([ "$aliases" -gt 0 ] && echo 0 || echo 1)" \
  "the theme aliases marks onto stock icon names" \
  "found none — every pinned upstream launcher will fall through to breeze-dark"

report "$([ -z "$broken" ] && echo 0 || echo 1)" \
  "every alias points at a mark that exists" \
  "$aliases checked:$(printf '%b' "$broken")"

echo
if [ "$fails" -gt 0 ]; then
  printf 'menu-icons: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'menu-icons: all checks passed (%d icons)\n' "$checked"
