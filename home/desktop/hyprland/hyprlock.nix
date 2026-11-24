# Lock screen — the Hyprland equivalent of kscreenlocker (kwin.nix).
# security.pam.services.hyprlock (system/hyprland.nix) is what lets this
# actually authenticate; without it the lock renders but every password is
# rejected.
{
  config,
  osConfig,
  lib,
  annixionColors,
  ...
}:
let
  compositing = osConfig.annixion.desktop.compositing;
  palette = config.annixion.desktop.hyprland.palette;
in
{
  programs.hyprlock = {
    enable = lib.mkDefault true;

    settings = {
      general = {
        hide_cursor = false;
        ignore_empty_input = true;
      };

      background = [
        {
          # Matches workspace.nix's flat void while #223 is still in flux.
          path = "${config.home.homeDirectory}/.dotfiles/assets/branding/wallpapers/void.png";
          blur_passes = if compositing then 2 else 0;
          blur_size = 4;
        }
      ];

      input-field = [
        {
          size = "300, 50";
          position = "0, -40";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = annixionColors.rgb palette.text;
          inner_color = annixionColors.rgb palette.surface;
          outer_color = annixionColors.rgb palette.accent;
          outline_thickness = 2;
          placeholder_text = "Password…";
        }
      ];

      label = [
        {
          text = "cmd[update:1000] echo \"$(date +'%H:%M')\"";
          font_size = 64;
          font_color = annixionColors.rgb palette.text;
          position = "0, 120";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
