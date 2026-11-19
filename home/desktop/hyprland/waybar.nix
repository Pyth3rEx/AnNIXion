# Status bar — the Hyprland equivalent of home/desktop/plasma/panel.nix.
{ lib, ... }:

{
  programs.waybar = {
    enable = lib.mkDefault true;
    systemd.enable = lib.mkDefault true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      spacing = 4;

      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right = [
        "pulseaudio"
        "network"
        "cpu"
        "memory"
        "clock"
        "tray"
      ];

      "hyprland/workspaces" = {
        format = "{icon}";
        on-click = "activate";
      };

      "hyprland/window" = {
        max-length = 60;
      };

      pulseaudio = {
        format = "VOL {volume}%";
        format-muted = "MUTED";
        on-click = "annixion-cc";
      };

      network = {
        format-wifi = "WIFI {signalStrength}%";
        format-ethernet = "NET {ifname}";
        format-disconnected = "NET down";
      };

      cpu.format = "CPU {usage}%";
      memory.format = "MEM {used:0.1f}G";

      clock = {
        format = "{:%H:%M  %Y-%m-%d}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      tray.spacing = 8;
    };

    # Palette from docs/visual-identity.md, shared with home/shell/omp-theme.nix.
    style = ''
      * {
        font-family: "JetBrains Mono", monospace;
        font-size: 13px;
      }

      window#waybar {
        background-color: #0e0f13;
        color: #dfe4ea;
        border-bottom: 1px solid #2e323d;
      }

      #workspaces button {
        padding: 0 8px;
        color: #dfe4ea;
        background: transparent;
      }

      #workspaces button.active {
        color: #ff0033;
        border-bottom: 2px solid #ff0033;
      }

      #window,
      #pulseaudio,
      #network,
      #cpu,
      #memory,
      #clock,
      #tray {
        padding: 0 10px;
      }

      #clock {
        color: #ff0033;
      }
    '';
  };
}
