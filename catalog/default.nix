# The catalog: one file per thing the menu or the icon theme shows.
#
# The directory tree *is* the menu tree. A directory holding _menu.nix is a menu
# node; every other .nix beside it is a tool inside that node. Nothing registers
# a tool anywhere — dropping the file in is the whole operation, and the package
# list, the .desktop entry, the menu XML and the icon all follow from it.
#
# Drawing rules: docs/visual-identity.md.
{ lib }:

let
  bodies = import ./bodies.nix;
  load = path: import path { inherit bodies; };

  isTool = name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "_menu.nix";
  isNode =
    dir: name: type:
    type == "directory" && builtins.pathExists (dir + "/${name}/_menu.nix");

  # annixion-1-recon-osint.directory -> menu-recon-osint. Derived rather than
  # stored, so a mark cannot end up named for a directory it no longer sits in.
  markOf =
    directory:
    if directory == "annixion.directory" then
      "menu-root"
    else
      let
        bare = lib.removeSuffix ".directory" (lib.removePrefix "annixion-" directory);
      in
      "menu-" + lib.elemAt (builtins.match "([0-9]+-)?(.*)" bare) 1;

  readNode =
    dir: path:
    let
      listing = builtins.readDir dir;
      menu = load (dir + "/_menu.nix");
      tools = lib.mapAttrs' (
        n: _:
        lib.nameValuePair (lib.removeSuffix ".nix" n) (
          load (dir + "/${n}")
          // {
            inherit path;
            inherit (menu) category;
          }
        )
      ) (lib.filterAttrs isTool listing);
    in
    menu
    // {
      inherit path tools;
      mark = menu.mark // {
        name = markOf menu.directory;
      };
      children = lib.sort (a: b: a.order < b.order) (
        lib.mapAttrsToList (n: _: readNode (dir + "/${n}") "${path}/${n}") (
          lib.filterAttrs (isNode dir) listing
        )
      );
    };

  menu = lib.sort (a: b: a.order < b.order) (
    lib.mapAttrsToList (n: _: readNode (./. + "/${n}") n) (
      lib.filterAttrs (isNode ./.) (builtins.readDir ./.)
    )
  );

  # Flatten: every node, and every tool in every node.
  allNodes = lib.concatMap (n: [ n ] ++ n.children) menu;
  allTools = lib.foldl' (acc: n: acc // n.tools) { } allNodes;

  # Installed system-wide but never shown — no menu entry, no mark.
  support = lib.mapAttrs' (
    n: _: lib.nameValuePair (lib.removeSuffix ".nix" n) (load (./support + "/${n}"))
  ) (lib.filterAttrs isTool (builtins.readDir ./support));

  # One drawing, four postures; the class colour is the whole difference.
  browsers = lib.mapAttrs' (
    n: _: lib.nameValuePair "firefox-${lib.removeSuffix ".nix" n}" (load (./browsers + "/${n}"))
  ) (lib.filterAttrs isTool (builtins.readDir ./browsers));

  root = load ./root.nix;
in
{
  inherit
    menu
    allNodes
    bodies
    root
    support
    ;

  tools = allTools;

  # Node by its path, so a tool earning a place under a second phase can name
  # that phase the way the tree already names it ("re/firmware").
  byPath = lib.listToAttrs (map (n: lib.nameValuePair n.path n) allNodes);

  # Everything the system installs. `p` is pkgs.
  packages =
    p:
    map (t: t.package p) (
      lib.filter (t: (t.package or null) != null) (lib.attrValues allTools ++ lib.attrValues support)
    );

  # Every mark the icon theme renders, keyed exactly as its SVG is named.
  marks =
    lib.mapAttrs (_: t: t.mark) allTools
    // browsers
    // lib.listToAttrs (map (n: lib.nameValuePair n.mark.name (removeAttrs n.mark [ "name" ])) allNodes)
    // {
      menu-root = root.mark;
      logo = load ./logo.nix;
    };
}
