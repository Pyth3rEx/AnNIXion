# Fastfetch system-info banner.
_:

{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "auto";
        source = "${./../assets/icons/AnNIXion.png}";
        width = 30;
      };
      display = {
        separator = ":";
        "constants" = [
          "───────────────────────────────"
          "                               "
        ];
        size = {
          binaryPrefix = "si";
        };
        color = {
          keys = "red";
          title = "red";
          custom = "red";
        };
        key = {
          width = 25;
          type = "both";
        };
      };
      modules = [
        # ── General stats ──────────────────────────────────
        {
          "type" = "custom";
          "format" = "┌─────{$1} GENERAL STATS {$1}────┐";
        }
        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }
        {
          type = "datetime";
          key = "Date";
          format = "{1}-{3}-{11}";
        }
        {
          type = "datetime";
          key = "Time";
          format = "{14}:{17}:{20}";
        }

        # ── Network configuration ──────────────────────────────────

        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }
        {
          "type" = "custom";
          "format" = "├──{$1} NETS CONFIGURATION {$1}──┤";
        }
        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }

        {
          "type" = "network";
          "interface" = [ "any" ];
          "format" = [
            "If: {interface}"
            "IPv4: {ipv4}"
            "IPv6: {ipv6}"
            "MAC: {mac}"
            "Rx: {rx}"
            "Tx: {tx}"
          ];
        }
        {
          "type" = "listening-ports";
          "protocol" = [
            "tcp"
            "udp"
          ];
          "format" = [
            "Ports: {count}"
            "Top: {top_list}"
          ];
          "maxItems" = 12;
        }
        {
          "type" = "wifi";
          "format" = [
            "WiFi: {ssid}"
            "Signal: {signal}"
            "Channel: {channel}"
          ];
          "enabled" = false;
        }
        {
          "type" = "connectivity";
          "targets" = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          "format" = [
            "Ping: {target} {result}"
          ];
          "enabled" = true;
        }
        {
          "type" = "dns";
          "format" = [
            "DNS: {nameservers}"
            "Search: {search_domains}"
          ];
        }
        {
          "type" = "route";
          "format" = [
            "Default: {default_gateway} via {default_interface}"
          ];
        }
        "bluetooth"
        "bluetoothradio"
        "netio"

        # ── Hardware configuration ──────────────────────────────────

        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }
        {
          "type" = "custom";
          "format" = "├{$1} HARDWARE CONFIGURATION {$1}┤";
        }
        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }

        "os"
        "kernel"
        "bios"
        "cpu"
        "gpu"

        # ── Usage statistics ──────────────────────────────────
        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }
        {
          "type" = "custom";
          "format" = "├───{$1} USAGE STATISTICS {$1}───┤";
        }
        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }

        {
          type = "memory";
          key = "Memory";
          percent = {
            type = 3;
            green = 30;
            yellow = 70;
          };
        }
        {
          type = "disk";
          key = "Disk";
          percent = {
            type = 3;
            green = 30;
            yellow = 70;
          };
        }
        {
          type = "battery";
          key = "Battery";
          percent = {
            type = 3;
            green = 70;
            yellow = 30;
          };
        }

        {
          "type" = "custom";
          "format" = "│{$2}                        {$2}│";
        }
        {
          "type" = "custom";
          "format" = "└{$1}────────────────────────{$1}┘";
        }

        "break"
        "colors"
      ];
    };
  };
}
