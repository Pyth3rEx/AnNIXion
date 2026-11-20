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
  centerModules = {
    power-profiles-daemon = {
      format = "{icon}";
      tooltip-format = "󰓅   {profile}\n󰒓   {driver}";
      format-icons = {
        default = "";
        performance = "";
        balanced = "󰶘";
        power-saver = "";
      };
    };
    "hyprland/workspaces" = {
      format = "{icon} {windows}";
      on-click = "activate";
      persistent-workspaces = {
        "*" = 5;
      };
      window-rewrite-default = "󰊠";
      window-rewrite = {
        kitty = "󰆍";
        onlyoffice = "󰏆";
        firefox = "";
        code = "󰨞";
        azahar = "";
        obsidian = "󰹕";
        mousepad = "󱓧";
        discord = "";
        spotify = "";
        "org.kde.kdeconnect.app" = "󰦉";
        "org.qbittorrent.qBittorrent" = "󰘿";
        xdg-desktop-portal-gtk = "";
        thunar = "";
        yazi = "󰇥";
        imv = "󰄄";
        swappy = "󰄄";
        "org.gnome.FileRoller" = "";
        vlc = "󰕼";
        mpv = "󰕼";
        blueman-manager = "";
        pavucontrol = "󱕂";
        nm-connection-editor = "󰐻";
        nwg-look = "󰒓";
        qt5ct = "󰒓";
        qt6ct = "󰒓";
        designer = "󰒓";
        linguist = "󰒓";
        assistant = "󰒓";
        pixeltool = "󰒓";
        qdbusviewer = "󰒓";
      };
      format-icons = {
        active = "󰮯";
        special = "󱁂";
        default = "󰊠";
        urgent = "󰧵";
        empty = "󰧟";
      };
      show-special = true;
      all-outputs = true;
    };
    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "󰛨";
        deactivated = "󰛩";
      };
      tooltip-format-activated = "System Focused";
      tooltip-format-deactivated = "Normal Mode";
    };
  };

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
    settings.mainBar = centerModules // {
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

      "group/distro-group" = {
        orientation = "horizontal";
        drawer = {
          transition-duration = 650;
          transition-left-to-right = true;
        };
        modules = [
          "custom/distro"
          "custom/terminal"
          "custom/code"
          "custom/obsidian"
          "custom/office"
          "custom/files"
          "custom/browser"
        ];
      };
      "group/storage" = {
        orientation = "horizontal";
        modules = [
          "disk"
          "memory"
        ];
      };
      "group/system" = {
        orientation = "horizontal";
        modules = [
          "temperature"
          "cpu"
        ];
      };
      "group/audio" = {
        orientation = "horizontal";
        drawer = {
          transition-duration = 650;
          transition-left-to-right = false;
        };
        modules = [
          "pulseaudio"
          "pulseaudio/slider"
          "pulseaudio#microphone"
        ];
      };
      "group/connections" = {
        orientation = "horizontal";
        drawer = {
          transition-duration = 500;
          transition-left-to-right = false;
        };
        modules = [
          "network"
          "bluetooth"
        ];
      };
      "group/tray-group" = {
        orientation = "horizontal";
        drawer = {
          transition-duration = 500;
          transition-left-to-right = false;
        };
        modules = [
          "custom/tray-arrow"
          "tray"
        ];
      };
      "custom/distro" = {
        # Placeholder — NixOS logo until this gets its own icon.
        format = "";
        tooltip = false;
      };
      "custom/terminal" = {
        format = "󰆍";
        on-click = "konsole";
        tooltip = false;
      };
      "custom/code" = {
        format = "󰨞";
        on-click = "codium";
        tooltip = false;
      };
      "custom/obsidian" = {
        format = "󰹕";
        on-click = "obsidian";
        tooltip = false;
      };
      "custom/office" = {
        format = "󰏆";
        on-click = "onlyoffice-desktopeditors";
        tooltip = false;
      };
      "custom/files" = {
        format = "󰉋";
        on-click = "dolphin";
        tooltip = false;
      };
      "custom/browser" = {
        format = "󰈹";
        on-click = "firefox";
        tooltip = false;
      };
      disk = {
        tooltip = false;
        interval = 3600;
        path = "/";
        format = "󱙋";
        format-alt = "󱙋 <span size='11pt'>{used}</span>";
        states = {
          warning = 80;
          critical = 90;
        };
      };
      memory = {
        tooltip = false;
        interval = 15;
        format = "󰍛";
        format-alt = "󰍛 <span size='11pt'>{used}</span>";
        states = {
          warning = 75;
          critical = 85;
        };
      };
      cpu = {
        tooltip = false;
        interval = 10;
        format = "󰻠";
        format-alt = "󰻠 <span size='11pt'>{usage}%</span>";
        states = {
          warning = 75;
          critical = 90;
        };
      };
      temperature = {
        tooltip = false;
        interval = 10;
        critical-threshold = 80;
        format = "{icon}";
        format-alt = "{icon} <span size='11pt'>{temperatureC}°C</span>";
        format-critical = "<span size='12pt'>󱗗 </span><span size='11pt'>{temperatureC}°C</span>";
        format-icons = [
          "󰜗"
          "󰔏"
          "󰸁"
        ];
      };

      pulseaudio = {
        format = "{icon}";
        format-muted = "󰝟";
        format-icons = {
          headphone = "󰋋";
          headset = "󰋋";
          hands-free = "󰋋";
          default = [
            ""
            ""
            ""
          ];
        };
        on-click = "pavucontrol";
        tooltip-format = "Output: {volume}%";
      };
      "pulseaudio#microphone" = {
        format = "{format_source}";
        format-source = "󰍬";
        format-source-muted = "󰍭";
      };
      "pulseaudio/slider" = {
        min = 0;
        max = 100;
        orientation = "horizontal";
      };
      network = {
        format-wifi = "{icon}";
        format-ethernet = "󰌗";
        format-linked = "󱘖";
        format-disconnected = "󰤣";
        format-disabled = "󰤮";
        format-icons = [
          "󰤯"
          "󰤟"
          "󰤢"
          "󰤥"
          "󰤨"
        ];
        tooltip-format-disconnected = "No Connection";
        tooltip-format-disabled = "Wi-Fi is OFF";
        tooltip-format-wifi = "󱄙  {essid} ({signalStrength}%)\n\n󰐻  Freq: {frequency}GHz\n  {bandwidthDownBytes}   {bandwidthUpBytes}";
        tooltip-format-ethernet = "󰈀  {ifname} (Connected)\n  {bandwidthDownBytes}   {bandwidthUpBytes}";
        tooltip-format-linked = "󱘖 {ifname}: No IP Address";
        on-click = "nm-applet --indicator";
        on-click-right = "pkill nm-applet";
        on-scroll-up = "nmcli radio wifi on";
        on-scroll-down = "nmcli radio wifi off";
      };
      bluetooth = {
        format = "󰂯";
        format-connected = "󰂱";
        format-disabled = "󰂲";
        tooltip-format = "{controller_alias} {status}";
        tooltip-format-connected = "󰐻  {num_connections} Connected:\n{device_enumerate}";
        tooltip-format-enumerate-connected-battery = "󰂱  {device_alias} (󰠠  {device_battery_percentage}%)";
        on-click = "blueman-manager";
        on-click-right = "rfkill toggle bluetooth";
      };
      battery = {
        interval = 60;
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} <span size='11pt'>{capacity}%</span>";
        format-full = "{icon} <span size='11pt'>{capacity}%</span>";
        format-charging = "<span size='12pt'>󱐌</span> <span size='11pt'>{capacity}%</span>";
        format-plugged = " <span size='11pt'></span>";
        format-alt = "{icon} <span size='11pt'>{time}</span>";
        tooltip-format = "{timeTo}\n\n󰠠  Usage: {power:0.1f}W\n󱤅  Condition: {health}%\n󱍸  Total: {cycles} cycles";
        format-icons = {
          default = [
            "󰂎"
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
        };
      };
      clock = {
        format = "󰃱 <span size='11pt'>{:%H.%M }</span>";
        format-alt = "󰃱 <span size='11pt'>{:%d %B %Y}</span>";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
      };
      "custom/tray-arrow" = {
        format = "{icon}";
        tooltip = false;
        format-icons = {
          notification = "󱅫";
          none = "󰏖";
          dnd-notification = "󰂠";
          dnd-none = "󰪓";
          inhibited-notification = "󰂛";
          inhibited-none = "󰪑";
          dnd-inhibited-notification = "󰂛";
          dnd-inhibited-none = "󰪑";
        };
        return-type = "json";
        exec-if = "which swaync-client";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };
      tray = {
        icon-size = 16;
        spacing = 10;
        show-passive-items = true;
      };
    };

    style = ''
      /* tokens/colors.css */
      /* Generated by matugen — do not edit manually */


      @define-color background #0f1416;

      @define-color error #ffb4ab;

      @define-color error_container #93000a;

      @define-color inverse_on_surface #2c3134;

      @define-color inverse_primary #08677f;

      @define-color inverse_surface #dee3e6;

      @define-color on_background #dee3e6;

      @define-color on_error #690005;

      @define-color on_error_container #ffdad6;

      @define-color on_primary #003544;

      @define-color on_primary_container #b8eaff;

      @define-color on_primary_fixed #001f28;

      @define-color on_primary_fixed_variant #004d61;

      @define-color on_secondary #1e333b;

      @define-color on_secondary_container #cfe6f1;

      @define-color on_secondary_fixed #071e26;

      @define-color on_secondary_fixed_variant #344a52;

      @define-color on_surface #dee3e6;

      @define-color on_surface_variant #bfc8cc;

      @define-color on_tertiary #2c2e4d;

      @define-color on_tertiary_container #e1e0ff;

      @define-color on_tertiary_fixed #171837;

      @define-color on_tertiary_fixed_variant #434465;

      @define-color outline #8a9296;

      @define-color outline_variant #40484c;

      @define-color primary #88d1ec;

      @define-color primary_container #004d61;

      @define-color primary_fixed #b8eaff;

      @define-color primary_fixed_dim #88d1ec;

      @define-color scrim #000000;

      @define-color secondary #b3cad4;

      @define-color secondary_container #344a52;

      @define-color secondary_fixed #cfe6f1;

      @define-color secondary_fixed_dim #b3cad4;

      @define-color shadow #000000;

      @define-color source_color #25738b;

      @define-color surface #0f1416;

      @define-color surface_bright #353a3d;

      @define-color surface_container #1b2023;

      @define-color surface_container_high #252b2d;

      @define-color surface_container_highest #303638;

      @define-color surface_container_low #171c1f;

      @define-color surface_container_lowest #0a0f11;

      @define-color surface_dim #0f1416;

      @define-color surface_tint #88d1ec;

      @define-color surface_variant #40484c;

      @define-color tertiary #c3c3eb;

      @define-color tertiary_container #434465;

      @define-color tertiary_fixed #e1e0ff;

      @define-color tertiary_fixed_dim #c3c3eb;


      /* Custom aliases */
      /*@define-color module-bg #1b2023;
      @define-color module-fg #dee3e6;
      @define-color bar-fg #88d1ec;
      @define-color inactive #8a9296;
      @define-color active-fg #003544;
      @define-color active-bg #88d1ec;
      @define-color accent #b3cad4;*/

      /* tokens/state.css */
      #custom-tray-arrow.inhibited-none,
      #custom-tray-arrow.dnd-none,
      #battery.charging,
      #power-profiles-daemon.power-saver {
        color: #a6e3a1;
      }


      #idle_inhibitor.activated,
      #cpu.warning,
      #disk.warning,
      #memory.warning,
      #battery.warning:not(.charging),
      #custom-tray-arrow.notification,
      #custom-tray-arrow.dnd-notification,
      #custom-tray-arrow.inhibited-notification {
        color: #f9e2af;
      }

      #network.disabled,
      #cpu.critical,
      #disk.critical,
      #memory.critical,
      #temperature.critical,
      #battery.critical:not(.charging),
      #power-profiles-daemon.performance,
      #custom-tray-arrow.dnd-inhibited-none,
      #custom-tray-arrow.dnd-inhibited-notification {
        color: #f38ba8;
      }

      /* tokens/workspace.css */

      #workspaces {
        margin: 4px 5px;
        padding: 6px 6px;
        background-color: @surface_container;
        border-radius: 20px;
      }

      #workspaces button {
        min-width: 32px;
        padding: 0 4px;
        margin: 0 2px;
        background: transparent;
        border-radius: 16px;
        color: @tertiary;
        transition: all 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94)
      }

      #workspaces button.active {
        padding: 0 12px;
        margin: 0 2px;
        background-color: @primary;
        color: @on_primary;
      }

      #workspaces button.special {
        color: @tertiary_fixed;
      }

      #workspaces button:hover {
        background-color: @surface_container_highest;
        color: @primary;
      }

      #workspaces button.active:hover {
        background-color: @primary;
        color: @on_primary;
      }

      #workspaces button.empty {
        color: @outline_variant;
      }

      #workspaces button.urgent {
        color: @error_container;
      }

      #workspaces button label:first-child {
        margin-right: 8px;
      }

      #workspaces button label:last-child {
        margin-left: 2px;
      }

      /* tokens/widget.css */

      /*======= MODULE INDEPENDENT =======*/
      #distro-group {
        margin: 4px 5px;
        background-color: @surface_container;
        border-radius: 20px;
        color: @primary;
      }

      #custom-distro {
        color: @primary;
        padding: 6px 15px 6px 10px;
      }

      #custom-terminal {
        color: #a6e3a1;
        padding: 0px 10px;
      }

      #custom-code {
        color: #89b4fa;
        padding: 0px 10px;
      }

      #custom-office {
        color: #ff6f4c;
        padding: 0px 10px;
      }

      #custom-obsidian {
        color: #cba6f7;
        padding: 0px 10px;
      }

      #custom-files {
        color: #f9e2af;
        padding: 0px 10px 0px 8px;
      }

      #custom-spotify {
        color: #1db954;
        padding: 0px 10px;
      }

      #custom-browser {
        color: #fab387;
        padding: 0px 15px 0px 10px;
      }

      #power-profiles-daemon,
      #idle_inhibitor {
        margin: 4px 5px;
        padding: 6px 15px 6px 10px;
        background-color: @surface_container;
        border-radius: 20px;
        color: @secondary_fixed_dim;
      }

      /*======= MODULE CAPSUL =======*/
      #audio,
      #connections,
      #system,
      #storage {
        margin: 4px 5px;
        padding: 6px 6px;
        background-color: @surface_container;
        border-radius: 20px;
        color: @secondary_fixed_dim;
      }

      #disk,
      #memory,
      #cpu,
      #temperature,
      #bluetooth {
        margin-right: 2px;
        padding: 0 8px;
      }

      #network {
        padding: 0px 10px 0px 4px;
      }

      #pulseaudio {
        margin-right: 12px;
        margin-left: 8px;
      }

      /*======= TRAY =======*/
      #tray-group {
        margin: 4px 5px;
        background-color: @surface_container;
        border-radius: 20px;
      }

      #custom-tray-arrow {
        padding: 6px 14px 6px 10px;
        color: @primary;
      }

      #tray {
        padding: 6px 10px;
      }

      #tray>.passive,
      #tray>.active,
      #tray>.needs-attention {
        -gtk-icon-effect: none;
      }

      /* tokens/batt-clock.css */

      #battery {
        margin: 4px 5px;
        padding: 6px 16px;
        background-color: @surface_container;
        border-radius: 20px;
        color: @secondary_fixed_dim;
      }

      #clock {
        margin: 4px 5px;
        padding: 6px 10px 6px 16px;
        background-color: @surface_container;
        border-radius: 20px;
        color: @secondary_fixed_dim;
      }

      /* tokens/slider.css */

      #pulseaudio-slider {
        margin: 4px 5px;
        padding: 0 2px;
        background-color: transparent;
        border-radius: 20px;
      }

      #pulseaudio-slider trough {
        min-height: 10px;
        min-width: 80px;
        border-radius: 10px;
        background-color: @outline_variant;
      }

      #pulseaudio-slider highlight {
        min-height: 10px;
        border-radius: 10px;
        background-color: @secondary_fixed_dim;
      }

      #pulseaudio-slider slider {
        min-height: 12px;
        min-width: 12px;
        margin: -2px 0;
        border-radius: 100%;
        background-color: @primary;
      }

      /* style.css */

      * {
        margin: 0;
        padding: 0;
        min-height: 0px;
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
      }

      window#waybar {
        background: transparent;
      }
    '';
  };
}
