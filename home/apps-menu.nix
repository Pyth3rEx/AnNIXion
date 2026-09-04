# Kill-chain application menu, derived from the catalog: the XDG menu tree, its
# .directory labels and every AnNIXion .desktop entry.
#
# Nothing here lists a tool. catalog/ is the list, and this file is the shape it
# takes once the desktop asks for it — so a tool that exists in the menu and not
# in the package set, or drawn but never shown, is no longer expressible.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  catalog = import ../catalog { inherit lib; };

  # ── Launchers ─────────────────────────────────────────────────────────────
  term = cmd: "konsole -e ${cmd}";
  # -name sets the WM_CLASS instance, so the window is tellable from a
  # plain Konsole — annixion-raise and the task manager both key on it.
  termNamed = wmName: cmd: "konsole -name ${wmName} -e ${cmd}";
  # Exported so the shell that takes over after the tool skips the banner.
  termHold = cmd: ''konsole -e zsh -c "export ANNIXION_NO_BANNER=1; ${cmd}; exec zsh"'';

  # The catalog is data and cannot reach config, so an exec that needs the home
  # directory says @home@ — the same trick a mark uses with @c@ for its colour.
  execOf =
    tool:
    let
      cmd = builtins.replaceStrings [ "@home@" ] [ config.home.homeDirectory ] tool.exec;
    in
    {
      gui = cmd;
      term = term cmd;
      hold = termHold cmd;
      named = termNamed tool.wmName cmd;
    }
    .${tool.launch};

  dir = name: icon: ''
    [Desktop Entry]
    Name=${name}
    Type=Directory
    Icon=${icon}
  '';

  # Raw .desktop text, written through home.file: xdg.desktopEntries lands
  # in the HM profile, which kbuildsycoca6 does not reliably index, so the
  # categories never appear.
  de =
    {
      name,
      exec,
      icon,
      categories,
      genericName ? null,
      comment ? null,
      mimeType ? null,
      noDisplay ? false,
      wmClass ? null,
    }:
    lib.concatStringsSep "\n" (
      [
        "[Desktop Entry]"
        "Type=Application"
        "Name=${name}"
      ]
      ++ lib.optional (genericName != null) "GenericName=${genericName}"
      ++ [
        "Icon=${icon}"
        "Exec=${exec}"
        "Terminal=false"
        "Categories=${lib.concatStringsSep ";" categories};"
      ]
      ++ lib.optional (comment != null) "Comment=${comment}"
      ++ lib.optional (mimeType != null) "MimeType=${lib.concatStringsSep ";" mimeType};"
      ++ lib.optional (wmClass != null) "StartupWMClass=${wmClass}"
      ++ lib.optional noDisplay "NoDisplay=true"
    )
    + "\n";

  # ── Menu XML ──────────────────────────────────────────────────────────────
  xml = builtins.replaceStrings [ "&" "<" ">" ] [ "&amp;" "&lt;" "&gt;" ];

  # A note sits above the Name it explains, its continuation lines aligned
  # under the opening "<!-- ".
  comment =
    pad: text:
    let
      lines = lib.splitString "\n" (lib.removeSuffix "\n" text);
      rest = map (l: "\n${pad}     ${l}") (lib.tail lines);
    in
    "${pad}<!-- ${lib.head lines}${lib.concatStrings rest} -->\n";

  # A node with children lists them; a leaf includes its category. No node
  # does both — a phase is a container or a menu, never half of each.
  node =
    depth: n:
    let
      pad = lib.concatStrings (lib.genList (_: "  ") depth);
      inner =
        if n.children == [ ] then
          "${pad}  <Include><Category>${n.category}</Category></Include>\n"
        else
          lib.concatMapStrings (node (depth + 1)) n.children;
    in
    "${pad}<Menu>\n"
    + lib.optionalString (n ? note) (comment "${pad}  " n.note)
    + "${pad}  <Name>${xml n.menuName}</Name>\n"
    + "${pad}  <Directory>${n.directory}</Directory>\n"
    + inner
    + "${pad}</Menu>\n";

  # The kill-chain phases are numbered; everything after them is not.
  killChain = lib.filter (n: n.order <= 10) catalog.menu;
  misc = lib.filter (n: n.order > 10) catalog.menu;

  # Drawn to width by hand rather than computed — the two rules do not share a
  # total, and lining them up matters more than deriving them.
  sections = {
    killChain = "  <!-- ── Kill-chain phases at root ──────────────────────────────── -->\n\n";
    misc = "  <!-- ── Misc tools ──────────────────────────────────────────────── -->\n\n";
  };

  # Depth 1: the '' below is dedented to the document root, so a top-level
  # phase sits two spaces in, under <Menu>.
  blocks = ns: lib.concatMapStrings (n: node 1 n + "\n") ns;

  menuXml = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <Directory>${catalog.root.directory}</Directory>

      <!-- Without these the tree resolves no entries at all; MergeFile
           keeps every non-AnNIXion app in the stock Plasma menu. -->
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <MergeFile type="parent"/>

  ''
  + sections.killChain
  + blocks killChain
  + sections.misc
  + blocks misc
  + "</Menu>\n";

  # ── Directory label & icon files ──────────────────────────────────────────
  directories = {
    ${catalog.root.directory} = dir catalog.root.label "annixion-menu-root";
  }
  // lib.listToAttrs (
    map (n: lib.nameValuePair n.directory (dir n.label "annixion-${n.mark.name}")) catalog.allNodes
  );

  # ── Desktop entries ───────────────────────────────────────────────────────
  desktopEntries = lib.mapAttrs' (
    key: tool:
    lib.nameValuePair "annixion-${key}" (de {
      inherit (tool) name;
      genericName = tool.genericName or null;
      comment = tool.comment or null;
      wmClass = tool.wmClass or null;
      icon = "annixion-${key}";
      exec = execOf tool;
      # The phase the tool lives under, then any it also earns a place in.
      categories = [ tool.category ] ++ map (p: catalog.byPath.${p}.category) (tool.alsoIn or [ ]);
    })
  ) catalog.tools;

in
{
  # Rebuild the KDE service cache once every file is on disk.
  home.activation.rebuildMenuCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD env XDG_DATA_DIRS="/etc/profiles/per-user/operator/share:${config.home.homeDirectory}/.nix-profile/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}" \
      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental 2>/dev/null || true
  '';

  # home.file lands these in ~/.local/share/ and ~/.config/ — the paths
  # kbuildsycoca6 always indexes.
  home.file =
    # NixOS sets XDG_MENU_PREFIX to "plasma-"; ship both names.
    lib.genAttrs [
      ".config/menus/applications.menu"
      ".config/menus/plasma-applications.menu"
    ] (_: lib.mkDefault { text = menuXml; })
    # .directory files → ~/.local/share/desktop-directories/
    // lib.mapAttrs' (
      n: t: lib.nameValuePair ".local/share/desktop-directories/${n}" { text = t; }
    ) directories
    # .desktop files → ~/.local/share/applications/
    // lib.mapAttrs' (
      n: t: lib.nameValuePair ".local/share/applications/${n}.desktop" { text = t; }
    ) desktopEntries;
}
