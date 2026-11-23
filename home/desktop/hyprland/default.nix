# Hyprland desktop, offered alongside home/desktop/plasma — #223. Panel,
# launcher, lock screen and wallpaper are declared here instead of inherited
# from Plasma, since none of plasma-manager's config applies to a different
# compositor.
{
  lib,
  ...
}:

{
  imports = [
    ./palette.nix
    ./workspace.nix
    ./binds.nix
    ./waybar
    ./wofi.nix
    ./hyprlock.nix
    ./hypridle.nix
  ];

  wayland.windowManager.hyprland = {
    enable = lib.mkDefault true;

    # system/hyprland.nix's programs.hyprland.enable installs the compositor,
    # the cap_sys_nice wrapper and the portal — home-manager only generates
    # the config file. Leaving these at their package defaults would pull in
    # a second, unwrapped Hyprland and a second portal registration.
    package = null;
    portalPackage = null;

    # home-manager 26.05 flips configType's own default to "lua" once
    # home.stateVersion reaches "26.05" (which home/default.nix's already
    # does) — pinned to the classic format since every binds.nix/workspace.nix
    # value below, and everything on the wiki, is written in it.
    configType = "hyprlang";

    systemd.enable = true;
  };
}
