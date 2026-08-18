# Desktop session: Plasma 6 on X11, SDDM, KDE extras.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ── Display & desktop — KDE Plasma 6 ────────────────────────────────────
  # X11 by default: Enhanced Session runs over xrdp, which has no Wayland
  # backend. Both sessions are offered at SDDM.

  services = {
    xserver.enable = lib.mkDefault true;
    displayManager.sddm.enable = lib.mkDefault true;
    displayManager.defaultSession = lib.mkDefault "plasma";
    desktopManager.plasma6.enable = lib.mkDefault true;
  };

  # ── KDE extras not pulled in automatically ──────────────────────────────
  environment.systemPackages = with pkgs; [
    kdePackages.kate
    kdePackages.ark
    kdePackages.kcalc
    kdePackages.filelight
    kdePackages.kwalletmanager
  ];

  # ── Default applications ────────────────────────────────────────────────
  xdg.mime.defaultApplications = {
    "text/html" = "firefox-red.desktop";
    "x-scheme-handler/http" = "firefox-red.desktop";
    "x-scheme-handler/https" = "firefox-red.desktop";
    "x-scheme-handler/about" = "firefox-red.desktop";
    "x-scheme-handler/unknown" = "firefox-red.desktop";
  };

  # ── Shell ───────────────────────────────────────────────────────────────
  programs.zsh.enable = lib.mkDefault true;
  users.users.operator.shell = pkgs.zsh;

  # ── KWallet ─────────────────────────────────────────────────────────────
  # Unlock the secret store on login.
  security.pam.services.sddm.enableKwallet = lib.mkDefault true;
}
