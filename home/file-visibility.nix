{
  config,
  lib,
  pkgs,
  ...
}:

# ============================================================
# FILE VISIBILITY
# ============================================================
# KDE, GTK and the search tools hide dotfiles independently, so each
# needs its own switch.
#
# Extensions need no setting — the whole filename is always rendered.
# Only .desktop files mask a name, showing Name= instead; KDE has no
# toggle and answers it by refusing untrusted ones.
# ============================================================

{
  # Not dolphinrc: GlobalViewProps means every folder reads this.
  home.file.".local/share/dolphin/view_properties/global/.directory".text = ''
    [Settings]
    HiddenFilesShown=true
  '';

  # GTK's chooser — Firefox and other non-Qt apps.
  dconf.settings = {
    "org/gtk/settings/file-chooser".show-hidden = true;
    "org/gtk/gtk4/settings/file-chooser".show-hidden = true;
  };

  # --hidden still honours .gitignore; add --no-ignore to drop that.
  programs.ripgrep = {
    enable = lib.mkDefault true;
    arguments = lib.mkDefault [ "--hidden" ];
  };

  programs.fd = {
    enable = lib.mkDefault true;
    hidden = lib.mkDefault true;
  };
}
