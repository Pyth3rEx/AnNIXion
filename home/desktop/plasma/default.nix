{
  lib,
  pkgs,
  ...
}:
# KDE Plasma desktop: panels, shortcuts and kwinrc/kdeglobals via
# plasma-manager, plus the activation hooks that re-apply what KWin resets.
{
  imports = [
    ./workspace.nix
    ./panel.nix
    ./shortcuts.nix
    ./kwin.nix
  ];

  programs.plasma = {
    enable = lib.mkDefault true;
    # Without this, KDE's own writes survive the rebuild and the declared
    # state is silently ignored.
    overrideConfig = lib.mkDefault true;
  };

  # KWin's session-state writes overwrite configFile on every logout, so
  # re-apply those keys before plasmashell restarts.
  home.activation.configureKwin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${DISPLAY:-}" ]; then
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group ModifierOnlyShortcuts --key Meta \
        "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu"
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Number 4
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Rows 1
    fi
  '';

  # Ordered after the widget install and the kwinrc writes.
  home.activation.restartPlasmashell = lib.hm.dag.entryAfter [ "installTiledMenu" "configureKwin" ] ''
    if [ -n "''${DISPLAY:-}" ]; then
      ${pkgs.kdePackages.plasma-workspace}/bin/plasmashell --replace \
        > /dev/null 2>&1 &
      disown 2>/dev/null || true
    fi
  '';
}
