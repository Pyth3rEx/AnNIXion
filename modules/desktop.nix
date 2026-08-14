{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ── DISPLAY & DESKTOP — KDE PLASMA 6 (X11 default, Wayland available) ───
  # X11 by default: Hyper-V Enhanced Session runs over xrdp, which has
  # no Wayland backend. Both sessions are offered at SDDM; override with
  # services.displayManager.defaultSession = "plasmawayland".

  services = {
    # X11 display server. Required for the default session and for xrdp.
    xserver.enable = lib.mkDefault true;

    # SDDM login manager — supports both X11 and Wayland Plasma sessions.
    displayManager.sddm.enable = lib.mkDefault true;

    # Only sets what SDDM pre-selects; Wayland stays available.
    displayManager.defaultSession = lib.mkDefault "plasma";

    # KDE Plasma 6 — enables both the X11 and Wayland session entries.
    desktopManager.plasma6.enable = lib.mkDefault true;
  };

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

  # Some KDE programs need enabling here, not via systemPackages.

  # Enable zsh system-wide and set it as the default shell for operator.
  programs.zsh.enable = lib.mkDefault true;
  users.users.operator.shell = pkgs.zsh;

  # KDE Wallet stores secrets (WiFi passwords, SSH keys etc.)
  # This makes it unlock automatically on login.
  security.pam.services.sddm.enableKwallet = lib.mkDefault true;
}
