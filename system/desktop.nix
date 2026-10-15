# Desktop session: Plasma 6 on X11, SDDM, KDE extras.
{
  lib,
  pkgs,
  ...
}:

{
  options.annixion.desktop.compositing = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = ''
      Let KWin composite the desktop.

      Off by default because the deployment target is a Hyper-V guest,
      where `hyperv_drm` gives a KMS display device and no render node:
      every frame is then rasterized by llvmpipe, which costs about
      three quarters of a core continuously (#167). Check for a node with
      `ls /dev/dri/renderD*` — if one exists, the GPU does that work
      instead and there is no reason to leave this off.

      On buys back blur, desktop animations and tear-free output. Off
      loses those; Krohnkite tiling, virtual desktops and the panel are
      unaffected, and the panel's adaptive opacity renders opaque.

      Read by home/desktop/plasma/kwin.nix, which writes kwinrc.
    '';
  };

  config = {
    # ── Display & desktop — KDE Plasma 6 ──────────────────────────────────
    # X11 by default: Enhanced Session runs over xrdp, which has no Wayland
    # backend. Both sessions are offered at SDDM. "plasma" is the Wayland
    # session — the X11 one is "plasmax11". Not mkDefault: plasma6 already
    # claims the option at that priority, which is how this came to read
    # "plasma" and quietly agree with it.

    services = {
      xserver.enable = lib.mkDefault true;
      displayManager.sddm.enable = lib.mkDefault true;
      displayManager.defaultSession = "plasmax11";

      # A Wayland greeter handing off to an X11 session is never reaped, and
      # its scope holds a second kwin_wayland for the whole uptime (#165).
      displayManager.sddm.wayland.enable = false;

      desktopManager.plasma6.enable = lib.mkDefault true;
    };

    # ── KDE extras not pulled in automatically ────────────────────────────
    environment.systemPackages = with pkgs; [
      kdePackages.kate
      kdePackages.ark
      kdePackages.kcalc
      kdePackages.filelight
      kdePackages.kwalletmanager
    ];

    # ── Default applications ──────────────────────────────────────────────
    xdg.mime.defaultApplications = {
      "text/html" = "firefox-osint.desktop";
      "x-scheme-handler/http" = "firefox-osint.desktop";
      "x-scheme-handler/https" = "firefox-osint.desktop";
      "x-scheme-handler/about" = "firefox-osint.desktop";
      "x-scheme-handler/unknown" = "firefox-osint.desktop";
      "text/markdown" = "annixion-glow.desktop";
    };

    # ── KWallet ───────────────────────────────────────────────────────────
    # Unlock the secret store on login.
    security.pam.services.sddm.enableKwallet = lib.mkDefault true;
  };
}
