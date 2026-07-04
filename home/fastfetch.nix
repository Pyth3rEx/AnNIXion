{ config, pkgs, ... }:

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
        separator = "  ";
        "constants" = [
          "──────────────────────────────────"
          "                                  "
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
          width = 15;
          type = "both";
        };
      };
      modules = [
        {
          "type" = "custom";
          "format" = "┌─────{$1} GENERAL STATS {$1}────┐";
        }
        {
          "type" = "custom";
          "format" = "│   {$2}                  {$2}   │";
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
        {
          "type" = "custom";
          "format" = "│   {$2}                  {$2}   │";
        }
        {
          "type" = "custom";
          "format" = "├{$1} HARDWARE CONFIGURATION {$1}┤";
        }
        {
          "type" = "custom";
          "format" = "│   {$2}                  {$2}   │";
        }

        "os"
        "kernel"
        "bios"
        "cpu"
        "gpu"

        {
          "type" = "custom";
          "format" = "│   {$2}                  {$2}   │";
        }
        {
          "type" = "custom";
          "format" = "├───{$1} USAGE STATISTICS {$1}───┤";
        }
        {
          "type" = "custom";
          "format" = "│   {$2}                  {$2}   │";
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
          "format" = "│   {$2}                  {$2}   │";
        }
        {
          "type" = "custom";
          "format" = "└{$1}────────────────────────{$1}┘";
        }
      ];
    };
  };
}
