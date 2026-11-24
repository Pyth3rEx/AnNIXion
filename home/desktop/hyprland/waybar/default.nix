# Status bar ported from haikal-hakim/athena's waybar rice, adapted to this catalog.
# Waybar stacks same-edge bars rather than overlapping them, so mainBar (eDP-1, every module) and centralBar (other displays, center cluster only) are two separate bars, not one merged by height.
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
    settings.centralBar = lib.mkDefault (
      centerModules
      // {
        layer = "top";
        height = 42;
        spacing = 6;
        # An exclusions-only "output" array needs a trailing "*" to fall through to everything else (man waybar).
        output = [
          "!eDP-1"
          "*"
        ];

        modules-center = centerModulesOrder;
      }
    );

    # Primary display (workspace "1" / eDP-1): the full bar.
    settings.mainBar = lib.mkDefault (
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
      }
    );

    style = lib.mkDefault (
      builtins.readFile ./tokens/colors.css
      + builtins.readFile ./tokens/state.css
      + builtins.readFile ./tokens/workspace.css
      + builtins.readFile ./tokens/widget.css
      + builtins.readFile ./tokens/batt-clock.css
      + builtins.readFile ./tokens/slider.css
      + builtins.readFile ./style.css
    );
  };
}
