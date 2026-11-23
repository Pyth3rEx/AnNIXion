# Launcher — the Hyprland equivalent of home/desktop/apps-menu.nix's Kicker
# entry point. apps-menu.nix already writes every catalog tool's .desktop
# file to ~/.local/share/applications regardless of desktop, so wofi's
# "drun" mode lists the full kill-chain menu with no catalog-side change.
{ lib, annixionCssPrelude, ... }:

{
  programs.wofi = {
    enable = lib.mkDefault true;

    settings = {
      show = "drun";
      prompt = "AnNIXion";
      width = 600;
      height = 400;
      location = "center";
      allow_markup = true;
      term = "konsole";
    };

    style = annixionCssPrelude + ''
      window {
        background-color: @menu_ground;
        color: @text;
        border: 1px solid @accent;
        font-family: "JetBrains Mono", monospace;
      }

      #input {
        margin: 6px;
        background-color: shade(@menu_ground, 1.3);
        color: @text;
        border: none;
      }

      #entry:selected {
        background-color: shade(@menu_ground, 1.3);
        border-left: 2px solid @accent;
      }

      #text {
        color: @text;
      }
    '';
  };
}
