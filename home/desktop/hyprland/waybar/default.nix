# Status bar — ported from haikal-hakim/athena's waybar rice
# (github.com/haikal-hakim/athena/tree/main/.config/waybar), with app
# launchers swapped for what's actually in this catalog (konsole, codium,
# dolphin — see binds.nix / home/apps/vscodium.nix / catalog/system/dolphin.nix),
# the spotify button dropped (not in the catalog), the hardcoded thermal-zone
# and timezone removed (hardware/locale specific to the upstream author), and
# the Tela-circle tray icon paths dropped (FHS paths that don't exist on NixOS).
#
# Waybar renders each `settings.*` entry as its own top-level bar window, and
# stacks same-edge bars one above the other rather than overlapping them — so
# centralBar and mainBar can't be merged into a single visual bar by just
# giving them the same height. Instead mainBar carries every module (left,
# center and right) and is pinned to the primary display only; centralBar
# repeats just the center cluster (workspaces/idle/power) for the other
# displays, which don't get the left/right system tray and launchers.
# "Primary" here is eDP-1 — workspace.nix pins Hyprland workspace "1" to it.
{ lib, pkgs, ... }:
let
  powerProfilesDaemonModule = import ./modules/power-profiles-daemon.nix;
  workspaceModule = import ./modules/workspace.nix;
  idleInhibitorModule = import ./modules/idle-inhibitor.nix;
  groupsModule = import ./modules/groups.nix;
  distroModule = import ./modules/distro.nix;
  storageModule = import ./modules/storage.nix;
  systemModule = import ./modules/system.nix;
  audioModule = import ./modules/audio.nix;
  connectionsModule = import ./modules/connections.nix;
  batteryModule = import ./modules/battery.nix;
  clockModule = import ./modules/clock.nix;
  trayNotifModule = import ./modules/tray-notif.nix;

  centerModules = powerProfilesDaemonModule // workspaceModule // idleInhibitorModule;

  centerModulesOrder = [
    "power-profiles-daemon"
    "hyprland/workspaces"
    "idle_inhibitor"
  ];
in

{
  home.packages = [ pkgs.pavucontrol ];

  programs.waybar = {
    enable = lib.mkDefault true;
    systemd.enable = lib.mkDefault true;

    # Secondary displays: workspaces/idle/power only, no launchers or tray.
    settings.centralBar = centerModules // {
      layer = "top";
      height = 42;
      spacing = 6;
      # A pure exclusion list matches nothing in waybar — an exclusions-only
      # array needs a trailing "*" to actually fall through to "everything
      # else" (see `man waybar`, the "output" entry).
      output = [
        "!eDP-1"
        "*"
      ];

      modules-center = centerModulesOrder;
    };

    # Primary display (workspace "1" / eDP-1): the full bar.
    settings.mainBar =
      centerModules
      // groupsModule
      // distroModule
      // storageModule
      // systemModule
      // audioModule
      // connectionsModule
      // batteryModule
      // clockModule
      // trayNotifModule
      // {
        layer = "top";
        height = 42;
        spacing = 6;
        output = "eDP-1";

        modules-left = [
          "group/distro-group"
          "group/storage"
          "group/system"
        ];
        modules-center = centerModulesOrder;
        modules-right = [
          "group/audio"
          "group/connections"
          "battery"
          "clock"
          "group/tray-group"
        ];
      };

    style =
      builtins.readFile ./tokens/colors.css
      + builtins.readFile ./tokens/state.css
      + builtins.readFile ./tokens/workspace.css
      + builtins.readFile ./tokens/widget.css
      + builtins.readFile ./tokens/batt-clock.css
      + builtins.readFile ./tokens/slider.css
      + builtins.readFile ./style.css;
  };
}
