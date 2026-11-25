# Status bar ported from haikal-hakim/athena's waybar rice, adapted to this catalog.
# Waybar stacks same-edge bars rather than overlapping them, so mainBar and centralBar are two separate bars, not one merged by height.
{
  lib,
  pkgs,
  config,
  osConfig,
  annixionCssPrelude,
  ...
}:
let
  primaryOutput = config.annixion.desktop.hyprland.waybar.primaryOutput;
  keyboardName = config.annixion.desktop.hyprland.waybar.keyboardName;
  offensiveEnabled = osConfig.annixion.offensiveNet.enable or false;
  compositing = osConfig.annixion.desktop.compositing;

  powerProfilesDaemonModule = import ./modules/power-profiles-daemon.nix;
  workspaceModule = import ./modules/workspace.nix;
  idleInhibitorModule = import ./modules/idle-inhibitor.nix;
  offensiveModeModule = import ./modules/offensive-mode.nix;
  groupsModule = import ./modules/groups.nix;
  distroModule = import ./modules/distro.nix;
  storageModule = import ./modules/storage.nix;
  systemModule = import ./modules/system.nix;
  audioModule = import ./modules/audio.nix;
  connectionsModule = import ./modules/connections.nix;
  networkInfoModule = import ./modules/network-info.nix;
  batteryModule = import ./modules/battery.nix;
  languageModule = lib.recursiveUpdate (import ./modules/language.nix) (
    lib.optionalAttrs (keyboardName != null) {
      "hyprland/language".keyboard-name = keyboardName;
    }
  );
  clockModule = import ./modules/clock.nix;
  trayNotifModule = import ./modules/tray-notif.nix;

  centerModules =
    powerProfilesDaemonModule
    // workspaceModule
    // idleInhibitorModule
    // lib.optionalAttrs offensiveEnabled offensiveModeModule;

  centerModulesOrder = lib.optional offensiveEnabled "custom/offensive-mode" ++ [
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

  options.annixion.desktop.hyprland.waybar.keyboardName = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "at-translated-set-2-keyboard";
    description = ''
      Device name (from `hyprctl devices -j`, under "keyboards") that the
      hyprland/language widget should read the active layout from.

      Hyprland reports every HID as a "keyboard" (power button, hotkey
      rails, video-bus, …), so without this pinned, waybar's module can
      land on one that throws a format error and permanently disables
      itself. Hardware-specific, so left unset here — set it in
      user/home.nix once you know your real keyboard's name.
    '';
  };

  config = {
    home.packages = [
      pkgs.pavucontrol
      pkgs.jq
    ];

    # Blur-behind for the same glass look as the windows (workspace.nix),
    # so the translucent capsules (tokens/*.css, @surface_glass) actually
    # show wallpaper through them instead of just a flat dim colour.
    wayland.windowManager.hyprland.settings.layerrule = lib.optionals compositing [
      {
        name = "waybar-blur";
        blur = "on";
        ignore_alpha = 0;
        "match:namespace" = "waybar";
      }
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
        // languageModule
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
            "hyprland/language"
            "clock"
            "group/tray-group"
          ];
        }
        // lib.optionalAttrs (primaryOutput != null) { output = primaryOutput; }
      );

      style = lib.mkDefault (
        annixionCssPrelude
        + "@define-color surface_glass alpha(@surface, 0.82);\n"
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
