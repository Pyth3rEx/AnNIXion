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
  #
  # Guarded on HYPRLAND_INSTANCE_SIGNATURE, not just DISPLAY: Hyprland's
  # XWayland sets DISPLAY too, so a home-manager activation run from inside
  # a Hyprland session (e.g. `nixos-rebuild switch` from a terminal there)
  # would otherwise launch Plasma's panel into a session that isn't Plasma's
  # — the KDE panel bleeding into Hyprland, reserving screen edges that
  # Hyprland then has to account for (#223).
  home.activation.restartPlasmashell = lib.hm.dag.entryAfter [ "installTiledMenu" "configureKwin" ] ''
    if [ -n "''${DISPLAY:-}" ] && [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      ${pkgs.kdePackages.plasma-workspace}/bin/plasmashell --replace \
        > /dev/null 2>&1 &
      disown 2>/dev/null || true
    fi
  '';
}
