# Launcher — the Hyprland equivalent of home/desktop/apps-menu.nix's Kicker
# entry point. apps-menu.nix already writes every catalog tool's .desktop
# file to ~/.local/share/applications regardless of desktop, so wofi's
# "drun" mode lists the full kill-chain menu with no catalog-side change.
{ lib, ... }:

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

    style = ''
      window {
        background-color: #0e0f13;
        color: #dfe4ea;
        border: 1px solid #ff0033;
        font-family: "JetBrains Mono", monospace;
      }

      #input {
        margin: 6px;
        background-color: #1a1d24;
        color: #dfe4ea;
        border: none;
      }

      #entry:selected {
        background-color: #1a1d24;
        border-left: 2px solid #ff0033;
      }

      #text {
        color: #dfe4ea;
      }
    '';
  };
}
