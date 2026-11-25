# Status bar ported from haikal-hakim/athena's waybar rice, adapted to this catalog.
# Waybar stacks same-edge bars rather than overlapping them, so mainBar and centralBar are two separate bars, not one merged by height.
{
  lib,
  pkgs,
  config,
  annixionCssPrelude,
  ...
}:
let
  primaryOutput = config.annixion.desktop.hyprland.waybar.primaryOutput;
  powerProfilesDaemonModule = import ./modules/power-profiles-daemon.nix;
  workspaceModule = import ./modules/workspace.nix;
  idleInhibitorModule = import ./modules/idle-inhibitor.nix;
  groupsModule = import ./modules/groups.nix;
  distroModule = import ./modules/distro.nix;
  storageModule = import ./modules/storage.nix;
  systemModule = import ./modules/system.nix;
  audioModule = import ./modules/audio.nix;
  connectionsModule = import ./modules/connections.nix;
  networkInfoModule = import ./modules/network-info.nix;
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
  options.annixion.desktop.hyprland.waybar.primaryOutput = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "eDP-1";
    description = ''
      Connector name of the output that gets the full waybar (launchers,
      tray, clock, …). Every other connected output falls back to
      centralBar, the lightweight workspaces/idle/power-only bar.

      Hyprland connector names (eDP-1, DP-5, …) are hardware-specific, so
      there's no agnostic default here — left unset, mainBar is shown on
      every output and centralBar is disabled. Set this in user/home.nix
      once you know your panel's name (`hyprctl monitors`).
    '';
  };

  config = {
    home.packages = [
      pkgs.pavucontrol
      pkgs.jq
    ];

    programs.waybar = {
      enable = lib.mkDefault true;
      systemd.enable = lib.mkDefault true;

      settings.centralBar = lib.mkIf (primaryOutput != null) (
        lib.mkDefault (
          centerModules
          // {
            layer = "top";
            height = 42;
            spacing = 6;
            output = [
              "!${primaryOutput}"
              "*"
            ];

            modules-center = centerModulesOrder;
          }
        )
      );

      settings.mainBar = lib.mkDefault (
        centerModules
        // groupsModule
        // distroModule
        // storageModule
        // systemModule
        // audioModule
        // connectionsModule
        // networkInfoModule
        // batteryModule
        // clockModule
        // trayNotifModule
        // {
          layer = "top";
          height = 42;
          spacing = 6;

          modules-left = [
            "group/distro-group"
            "group/storage"
            "group/system"
            "group/connections"
            "custom/network-info"
          ];
          modules-center = centerModulesOrder;
          modules-right = [
            "group/audio"
            "battery"
            "clock"
            "group/tray-group"
          ];
        }
        // lib.optionalAttrs (primaryOutput != null) { output = primaryOutput; }
      );

      style = lib.mkDefault (
        annixionCssPrelude
        + builtins.readFile ./tokens/state.css
        + builtins.readFile ./tokens/workspace.css
        + builtins.readFile ./tokens/widget.css
        + builtins.readFile ./tokens/batt-clock.css
        + builtins.readFile ./tokens/slider.css
        + builtins.readFile ./tokens/glass.css
        + builtins.readFile ./style.css
      );
    };
  };
}
