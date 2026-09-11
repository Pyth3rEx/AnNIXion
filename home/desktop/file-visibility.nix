# File visibility: KDE, GTK and the search tools hide dotfiles
# independently, so each needs its own switch (docs/hardening.md).
{
  lib,
  ...
}:

{
  home.file.".local/share/dolphin/view_properties/global/.directory".text = ''
    [Settings]
    HiddenFilesShown=true
  '';

  # GlobalViewProps defaults to true, which is what makes every folder read
  # the .directory file above instead of its own per-folder properties — but
  # it's pinned explicitly rather than trusted, since a first-run Dolphin
  # wizard or a stray dolphinrc write is enough to flip it to per-folder mode
  # and silently strand the setting above.
  programs.plasma.configFile."dolphinrc"."General"."GlobalViewProps" = true;

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
