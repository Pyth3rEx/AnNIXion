# Look and feel: layout, theming and wallpaper. The Hyprland equivalent of
# home/desktop/plasma/workspace.nix and kwin.nix.
{
  config,
  osConfig,
  lib,
  annixionColors,
  ...
}:
let
  palette = config.annixion.desktop.hyprland.palette;
  compositing = osConfig.annixion.desktop.compositing;
  wallpapers = "${config.home.homeDirectory}/.dotfiles/assets/branding/wallpapers";
in
{
  services.hyprpaper = {
    enable = lib.mkDefault true;
    settings = {
      preload = [ "${wallpapers}/void.png" ];
      wallpaper = [
        {
          monitor = "";
          path = "${wallpapers}/wallpaper_1.png";
        }
      ];
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  wayland.windowManager.hyprland.settings = {
    # Hardware-agnostic fallback — one monitor, best mode Hyprland can find.
    # Real layouts are machine-specific: set them in user/home.nix, which wins over this
    # mkDefault with no lib.mkForce needed.
    monitor = lib.mkDefault [ ",preferred,auto,1" ];

    # ── Cursor & fonts ────────────────────────────────────────
    env = [
      "XCURSOR_THEME,Nordzy-cursors"
      "XCURSOR_SIZE,32"
      "HYPRCURSOR_THEME,Nordzy-cursors"
      "HYPRCURSOR_SIZE,32"
    ];

    # ── General ───────────────────────────────────────────────
    general = {
      gaps_in = 5;
      gaps_out = 10;
      border_size = 1;
      "col.active_border" = annixionColors.rgba palette.accent 20;
      "col.inactive_border" = annixionColors.rgba palette.surface 67;
      layout = "dwindle";
    };

    dwindle = {
      preserve_split = true;
    };

    decoration = {
      rounding = 6;
      blur = {
        enabled = compositing;
        size = 6;
        passes = 2;
        ignore_opacity = true;
      };
      shadow.enabled = compositing;
      active_opacity = 1.0;
      inactive_opacity = 0.85;
    };

    animations.enabled = compositing;

    windowrule = [
      "opacity 1.0 override 1.0 override, match:fullscreen 1"
      "opacity 0.9 override 0.82 override, match:float 1"
      "opacity 0.88 override 0.8 override, match:class ^(konsole)$"
    ];

    # Single click selects, focus follows mouse
    input = {
      follow_mouse = 1;
      accel_profile = "flat";
    };

    cursor.no_warps = true;

    misc = {
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      force_default_wallpaper = 0;
    };
  };
}
