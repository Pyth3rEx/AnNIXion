# kwinrc and kdeglobals: the Krohnkite tiling script and the window
# behaviour KWin will not take from anywhere else.
_: {
  programs.plasma = {

    # ── KWin config (Krohnkite tiling script) ─────────────────
    # No lib.mkDefault: configFile is opaque attrs that plasma-manager
    # also writes at normal priority, so mkDefault loses the whole block
    # instead of merging.
    configFile = {
      "kwinrc"."Plugins"."krohnkiteEnabled" = true;

      # Virtual desktops
      "kwinrc"."Desktops"."Number" = 4;
      "kwinrc"."Desktops"."Rows" = 1;

      # Window behaviour
      "kwinrc"."Windows"."FocusPolicy" = "FocusFollowsMouse";
      "kwinrc"."Windows"."FocusStealingPreventionLevel" = 1;

      # Compositor — minimal effects for VM performance
      "kwinrc"."Compositing"."AnimationSpeed" = 3;
      "kwinrc"."Compositing"."Enabled" = true;

      # Indexing file contents means parsing them.
      "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;

      # Dolphin's own view is set in home/desktop/file-visibility.nix.
      "kdeglobals"."KFileDialog Settings"."Show Hidden Files" = true;

      # TiledMenu registers as an Application Launcher applet, so this
      # D-Bus method toggles it.
      "kwinrc"."ModifierOnlyShortcuts"."Meta" =
        "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu";

      # ── Krohnkite ───────────────────────────────────────────
      "kwinrc"."Script-krohnkite"."enableTileLayout" = true;
      "kwinrc"."Script-krohnkite"."screenGapTop" = 8;
      "kwinrc"."Script-krohnkite"."screenGapBottom" = 8;
      "kwinrc"."Script-krohnkite"."screenGapLeft" = 8;
      "kwinrc"."Script-krohnkite"."screenGapRight" = 8;
      "kwinrc"."Script-krohnkite"."tileLayoutGap" = 8;
      "kwinrc"."Script-krohnkite"."masterRatio" = "0.55";
    };
  };
}
