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
        size = {
          binaryPrefix = "si";
        };
        color = {
          "keys" = "red";
          "title" = "red";
        };
      };
      modules = [
        "title"
        "separator"
        {
          "type" = "os";
          "key" = "OS";
          "format" = "{name} {version}";
        }
        {
          "type" = "kernel";
          "key" = "Kernel";
        }
        {
          "type" = "memory";
          "key" = "Memory";
          "percent" = {
            "type" = 3;
            "green" = 30;
            "yellow" = 70;
          };
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
        "break"
        "player"
        "media"
      ];
    };
  };
}
