#!/usr/bin/env bash
# The catalog is the single declaration of every tool: its package, its menu
# entry and its mark. Collapsing three lists into one removed the drift they
# used to hide, but it introduces its own ways to be wrong — a tool in a folder
# with no _menu.nix is silently invisible, an alsoIn naming a phase that does
# not exist is silently dropped, two nodes claiming one category silently merge.
# None of these error: the menu just comes out missing something.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HM='.#nixosConfigurations.AnNIXion-ci.config.home-manager.users.operator'
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

catalog=$(nix eval --impure --json --expr '
  let
    pkgs = import <nixpkgs> { };
    inherit (pkgs) lib;
    c = import ./catalog { inherit lib; };
    node = n: {
      inherit (n) path order directory;
      category = n.category or null;
      mark = n.mark.name;
      tools = builtins.attrNames n.tools;
      children = map (x: x.path) n.children;
    };
  in
  {
    nodes = map node c.allNodes;
    tools = lib.mapAttrs (_: t: {
      inherit (t) path category;
      hasPackage = (t.package or null) != null;
      alsoIn = t.alsoIn or [ ];
      launch = t.launch;
      wmName = t.wmName or null;
    }) c.tools;
    marks = builtins.attrNames c.marks;
    support = builtins.attrNames c.support;
  }
' 2>&1)

if ! jq -e . >/dev/null 2>&1 <<<"$catalog"; then
  printf 'catalog: could not evaluate\n%s\n' "$catalog"
  exit 1
fi

q() { jq -r "$1" <<<"$catalog"; }

# ── The tree is well formed ────────────────────────────────────────────────
report "$([ "$(q '.nodes | length')" -gt 0 ] && echo 0 || echo 1)" \
  "the catalog finds menu nodes" "readDir found none — is _menu.nix missing?"

# A node either contains sub-menus or lists tools. One that does both puts its
# tools somewhere the XML has no Include for, so they vanish from the menu.
both=$(q '[.nodes[] | select((.children | length) > 0 and (.tools | length) > 0) | .path] | join(", ")')
report "$([ -z "$both" ] && echo 0 || echo 1)" \
  "no node holds both sub-menus and tools" \
  "these would lose their tools from the menu: $both"

# A leaf with no category has no Include, so nothing it holds is ever shown.
nocat=$(q '[.nodes[] | select((.children | length) == 0 and .category == null) | .path] | join(", ")')
report "$([ -z "$nocat" ] && echo 0 || echo 1)" \
  "every leaf node declares a category" "no Include would be written for: $nocat"

dupcat=$(q '[.nodes[] | select(.category != null) | .category] | group_by(.) | map(select(length > 1) | .[0]) | join(", ")')
report "$([ -z "$dupcat" ] && echo 0 || echo 1)" \
  "no two nodes claim the same category" "the menu would show these twice: $dupcat"

duporder=$(q '[.nodes[] | {parent: (.path | split("/") | .[0:-1] | join("/")), order}]
  | group_by(.parent) | map(select((map(.order) | unique | length) != length) | .[0].parent)
  | join(", ")')
report "$([ -z "$duporder" ] && echo 0 || echo 1)" \
  "sibling nodes have distinct orders" "the menu order is undefined under: $duporder"

# ── Tools ──────────────────────────────────────────────────────────────────
paths=$(q '[.nodes[].path] | sort | join(" ")')
bad=""
while read -r tool also; do
  [ -z "$also" ] && continue
  for p in $also; do
    case " $paths " in
      *" $p "*) ;;
      *) bad="$bad $tool->$p" ;;
    esac
  done
done < <(q '.tools | to_entries[] | "\(.key) \(.value.alsoIn | join(" "))"')
report "$([ -z "$bad" ] && echo 0 || echo 1)" \
  "every alsoIn names a real node" "these second placements resolve nowhere:$bad"

# A "named" launch is the only kind that carries a WM_CLASS, and it is the
# thing annixion-raise keys on; without it the window is untellable.
nowm=$(q '[.tools | to_entries[] | select(.value.launch == "named" and .value.wmName == null) | .key] | join(", ")')
report "$([ -z "$nowm" ] && echo 0 || echo 1)" \
  "every named launch carries a wmName" "no WM_CLASS to raise by: $nowm"

# shellcheck disable=SC2016 # a jq program: $l is jq's variable, not the shell's
launch=$(q '[.tools[].launch] | unique | map(select(. as $l | ["gui","term","hold","named"] | index($l) | not)) | join(", ")')
report "$([ -z "$launch" ] && echo 0 || echo 1)" \
  "every launch kind is one the menu can build" "unknown: $launch"

# ── Marks ──────────────────────────────────────────────────────────────────
# The theme is one flat directory, so two marks under one name means one
# silently overwrites the other.
dupmark=$(q '.marks | group_by(.) | map(select(length > 1) | .[0]) | join(", ")')
report "$([ -z "$dupmark" ] && echo 0 || echo 1)" \
  "mark names are unique" "these would overwrite each other: $dupmark"

# Every tool must be drawn: an entry whose Icon= resolves nowhere is a blank
# square in the menu. menu-icons.sh proves the rendered theme; this proves the
# source, and says which file is at fault rather than which icon name.
undrawn=$(q '[.tools | keys[]] - .marks | join(", ")')
report "$([ -z "$undrawn" ] && echo 0 || echo 1)" \
  "every tool has a mark" "no drawing for: $undrawn"

# ── The catalog and the built menu agree ───────────────────────────────────
want=$(q '.tools | length')
got=$(nix eval --json "$HM.home.file" --apply '
  f: builtins.length (builtins.filter
       (n: builtins.match ".*/applications/annixion-.*\\.desktop" n != null)
       (builtins.attrNames f))' 2>/dev/null)
report "$([ "$want" = "${got:-x}" ] && echo 0 || echo 1)" \
  "every catalog tool reaches the menu" \
  "catalog declares $want tools, the desktop gets ${got:-<none>} entries"

echo
if [ "$fails" -gt 0 ]; then
  printf 'catalog: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'catalog: all checks passed (%s tools, %s nodes, %s marks)\n' \
  "$want" "$(q '.nodes | length')" "$(q '.marks | length')"
