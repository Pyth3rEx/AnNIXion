{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ============================================================
  # DISPLAY & DESKTOP — KDE PLASMA 6 (X11 default, Wayland available)
  # ============================================================
  # AnNIXion is designed to run both on bare metal and inside Hyper-V.
  # Both sessions are available at the SDDM login screen; X11 is the
  # default for two reasons:
  #
  #   1. Hyper-V Enhanced Session runs over xrdp, which has no Wayland
  #      backend. Without X11, you lose clipboard, audio, dynamic
  #      resolution, and USB redirection — the session becomes unusable.
  #
  #   2. X11 works on bare metal too, so the out-of-the-box experience
  #      is consistent across both deployment contexts.
  #
  # If you are on bare metal and prefer Wayland, override the default
  # session in user/configuration.nix:
  #
  #   services.displayManager.defaultSession = "plasmawayland";
  #
  # SDDM remembers your last session choice per user, so you only need
  # to switch once at the login screen — it will stick on the next boot.

  # X11 display server. Required for the default session and for xrdp.
  services.xserver.enable = lib.mkDefault true;

  # SDDM login manager — supports both X11 and Wayland Plasma sessions.
  services.displayManager.sddm.enable = lib.mkDefault true;

  # Default to the X11 Plasma session ("plasma").
  # The Wayland session ("plasmawayland") is still listed in SDDM and
  # fully usable — this only controls what SDDM pre-selects on first boot.
  services.displayManager.defaultSession = lib.mkDefault "plasma";

  # KDE Plasma 6 — enables both the X11 and Wayland session entries.
  services.desktopManager.plasma6.enable = lib.mkDefault true;

  # KDE extras that aren't pulled in automatically
  environment.systemPackages = with pkgs; [
    kdePackages.kate # KDE text editor
    kdePackages.ark # archive manager
    kdePackages.kcalc # calculator
    kdePackages.filelight # disk usage visualizer
    kdePackages.kwalletmanager
  ];

  # Default applications
  xdg.mime.defaultApplications = {
    "text/html" = "firefox-red.desktop";
    "x-scheme-handler/http" = "firefox-red.desktop";
    "x-scheme-handler/https" = "firefox-red.desktop";
    "x-scheme-handler/about" = "firefox-red.desktop";
    "x-scheme-handler/unknown" = "firefox-red.desktop";
  };

  # Some KDE programs need to be enabled this way rather than
  # just added to systemPackages.
  # programs.firefox.enable = lib.mkDefault true;

  # Enable zsh system-wide and set it as the default shell for operator.
  programs.zsh.enable = lib.mkDefault true;
  users.users.operator.shell = pkgs.zsh;

  # KDE Wallet stores secrets (WiFi passwords, SSH keys etc.)
  # This makes it unlock automatically on login.
  security.pam.services.sddm.enableKwallet = lib.mkDefault true;
}
