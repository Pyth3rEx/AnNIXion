{ config, pkgs, ... }:

{
  programs.onlyoffice = {
    enable = true;
    package = pkgs.onlyoffice-desktopeditors;
    settings = {
      UITheme = "theme-night";
      editorWindowMode = false;
      forcedRtl = false;
      maximized = true;
      titlebar = "custom";
    };
  };
}
