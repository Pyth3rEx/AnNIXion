# Hyprland session, offered at SDDM alongside KDE Plasma (system/desktop.nix).
# #223 tracks the eventual move off Plasma; this lands Hyprland first, side
# by side, so both can be compared on real hardware before anything is
# retired. Validated on bare metal only for now — Hyper-V keeps Plasma (see
# the module doc-comment below) and VMware support is follow-up work.
{
  lib,
  ...
}:

{
  # Pulls in the compositor, the security wrapper it needs for SCHED_RR, the
  # XWayland and portal packages, and registers the session with SDDM via
  # services.displayManager.sessionPackages — all handled by the upstream
  # module. services.displayManager.defaultSession is left as "plasmax11"
  # (system/desktop.nix): Hyprland is a second choice at the login screen,
  # not the default.
  #
  # Hyper-V's Enhanced Session (system/xrdp.nix) never reads SDDM's session
  # list at all — it launches startplasma-x11 directly as xrdp's
  # defaultWindowManager — so adding a session here cannot touch that path,
  # and Hyper-V stays on Plasma/X11 untouched, as #223 intends.
  programs.hyprland.enable = lib.mkDefault true;

  # home-manager only ships hyprlock's config (home/desktop/hyprland/); the
  # PAM stack behind it is a system concern.
  security.pam.services.hyprlock = { };
}
