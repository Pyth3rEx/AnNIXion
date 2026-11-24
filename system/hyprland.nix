# Hyprland session offered at SDDM alongside Plasma (system/desktop.nix) — #223, validated bare-metal only; Hyper-V stays on Plasma via xrdp's own path regardless.
{
  lib,
  ...
}:

{
  # services.displayManager.defaultSession stays "plasmax11" — Hyprland is a second choice at the login screen, not the default.
  programs.hyprland.enable = lib.mkDefault true;

  # home-manager only ships hyprlock's config; the PAM stack behind it is a system concern.
  security.pam.services.hyprlock = { };
}
