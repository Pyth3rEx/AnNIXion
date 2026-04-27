{ config, lib, pkgs, ... }:

{
  # ============================================================
  # DISPLAY & DESKTOP — KDE PLASMA 6 (X11)
  # ============================================================

  # Exclude Konsole — we use xterm+tmux as the default terminal
  environment.plasma6.excludePackages = lib.mkDefault (with pkgs.kdePackages; [ konsole ]);

  # X11 display server — KDE runs on top of this.
  services.xserver.enable = lib.mkDefault true;

  # SDDM is KDE's login screen. It's the one that knows how to
  # launch a proper Plasma session for both local and xrdp use.
  services.displayManager.sddm.enable = lib.mkDefault true;

  # KDE Plasma 6 — the full desktop environment.
  services.desktopManager.plasma6.enable = lib.mkDefault true;

  # KDE extras that aren't pulled in automatically
  environment.systemPackages = with pkgs; [
    kdePackages.kate           # KDE text editor
    kdePackages.ark            # archive manager
    kdePackages.kcalc          # calculator
    kdePackages.filelight      # disk usage visualizer
    kdePackages.kwalletmanager
  ];

  # Some KDE programs need to be enabled this way rather than
  # just added to systemPackages.
  programs.firefox.enable = lib.mkDefault true;

  # KDE Wallet stores secrets (WiFi passwords, SSH keys etc.)
  # This makes it unlock automatically on login.
  security.pam.services.sddm.enableKwallet = lib.mkDefault true;
}