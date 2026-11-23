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
  # Off by default on a Hyper-V guest with no render node (#167) — the same
  # gate kwin.nix reads for KWin's compositor. Hyprland always composites
  # (that's inherent to Wayland), so what this buys back here is blur and
  # animations rather than compositing itself.
  compositing = osConfig.annixion.desktop.compositing;

  wallpapers = "${config.home.homeDirectory}/.dotfiles/assets/branding/wallpapers";
in
{
  services.hyprpaper = {
    enable = lib.mkDefault true;
    settings = {
      # Swapped to a flat void (palette.ground, docs/visual-identity.md's
      # "Deepest ground") while the #223 identity pivot is still in flux — a
      # clean base to design the new chrome against instead of the current
      # graffiti art. Point back at wallpaper_1.png once that's settled.
      preload = [ "${wallpapers}/void.png" ];
      wallpaper = [ ", ${wallpapers}/void.png" ];
    };
  };

  wayland.windowManager.hyprland.settings = {
    # Hardware-agnostic fallback — one monitor, best mode Hyprland can find.
    # Real layouts (output wiring, workspace-to-output pinning) are
    # machine-specific: set them in user/home.nix, which wins over this
    # mkDefault with no lib.mkForce needed.
    monitor = lib.mkDefault [ ",preferred,auto,1" ];

    # ── Cursor & fonts ────────────────────────────────────────
    # Same theme and size as programs.plasma.workspace.cursor, so a monitor
    # shared between sessions does not change pointer size switching desktops.
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
      border_size = 2;
      # palette.accent, the signature accent (docs/visual-identity.md),
      # active; palette.surface, the raised-surface neutral, inactive.
      "col.active_border" = annixionColors.rgba palette.accent 93;
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
      };
      shadow.enabled = compositing;
    };

    animations.enabled = compositing;

    # Single click selects, focus follows mouse — the same choice
    # home/desktop/plasma/workspace.nix makes, for the reason noted there
    # (#171): a click landing while the pointer is still moving opens
    # whatever was under it, and focus-follows-mouse makes that easy to do.
    input = {
      follow_mouse = 1;
      accel_profile = "flat";
    };

    misc = {
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      # KWin starts on 4 virtual desktops (kwin.nix); Hyprland's analogue is
      # workspaces, bound 1-4 in binds.nix — nothing to configure here.
      force_default_wallpaper = 0;
    };
  };
}
