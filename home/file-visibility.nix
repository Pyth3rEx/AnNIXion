{
  config,
  lib,
  pkgs,
  ...
}:

# ============================================================
# FILE VISIBILITY
# ============================================================
# A hidden file is one you cannot judge. On a machine used to handle
# other people's artefacts, concealment is the wrong default, so KDE,
# GTK and the search tools are each told to stop doing it — they hide
# dotfiles independently, so each needs its own switch.
#
# Extensions need no setting: Dolphin and the KDE file dialogs always
# render the whole filename, and there is no Windows-style "hide known
# extensions" behaviour to turn off. The one thing that still masks a
# name is a .desktop file, which shows its Name= field instead of the
# filename it actually has. KDE offers no toggle for that; what it does
# instead is refuse to run a .desktop file that is not both executable
# and trusted, which is the mitigation that matters.
# ============================================================

{
  # Dolphin keeps view properties out of dolphinrc. GlobalViewProps
  # defaults to true, so every folder reads this one file.
  home.file.".local/share/dolphin/view_properties/global/.directory".text = ''
    [Settings]
    HiddenFilesShown=true
  '';

  # GTK's file chooser, which is what Firefox and other non-Qt apps use.
  dconf.settings = {
    "org/gtk/settings/file-chooser".show-hidden = true;
    "org/gtk/gtk4/settings/file-chooser".show-hidden = true;
  };

  # rg and fd both skip dotfiles by default, which excludes exactly the
  # directories things get left in. --hidden still honours .gitignore;
  # add --no-ignore if you want that gone too.
  programs.ripgrep = {
    enable = lib.mkDefault true;
    arguments = lib.mkDefault [ "--hidden" ];
  };

  programs.fd = {
    enable = lib.mkDefault true;
    hidden = lib.mkDefault true;
  };
}
