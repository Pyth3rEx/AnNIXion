# Look and feel: theme, cursor, icons, wallpaper and the interface face.
{
  config,
  lib,
  ...
}:
{
  programs.plasma = {

    # ── Global aesthetics ────────────────────────────────────
    workspace = lib.mkDefault {
      # Single click selects; double click opens. The other way round, a
      # click that lands while the pointer is moving opens whatever was
      # under it (#171) — and FocusFollowsMouse makes that easy to do.
      clickItemTo = "select";
      lookAndFeel = "org.kde.breezedark.desktop";
      cursor = {
        theme = "Nordzy-cursors";
        size = 32;
      };
      # AnNIXion carries the menu marks and inherits Slot-Dark-Icons for
      # everything else. The Colorize theme it replaced shipped places only,
      # so every application icon fell through to stock breeze-dark.
      iconTheme = "AnNIXion";
      wallpaper = "${config.home.homeDirectory}/.dotfiles/assets/branding/wallpapers/wallpaper_1.png";
      wallpaperFillMode = "preserveAspectFit";
      wallpaperBackground.color = "#000000";
    };

    kscreenlocker.appearance.wallpaper = "${config.home.homeDirectory}/.dotfiles/assets/branding/wallpapers/wallpaper_2.png";

    fonts = {
      general = {
        family = "JetBrains Mono";
        pointSize = 12;
      };
    };
  };
}
