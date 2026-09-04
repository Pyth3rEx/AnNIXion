# ── Hardening — attack surface reduction ─────────────────────────────────
# Priority 900 beats an upstream mkDefault (1000) and loses to
# user/configuration.nix (100), so restoring anything is one line.
# What is disabled, and what is deliberately left alone: docs/hardening.md
{
  lib,
  pkgs,
  ...
}:

let
  harden = lib.mkOverride 900;
in
{
  # Was the only remotely reachable service, with password auth.
  services.openssh.enable = harden false;

  networking.modemmanager.enable = harden false;
  services.power-profiles-daemon.enable = harden false;

  # Screen reader, on by default; pulls in speechd and at-spi2.
  # Accessibility: re-enable orca and the other two follow.
  services.orca.enable = harden false;
  services.speechd.enable = harden false;

  networking.firewall = {
    enable = harden true;
    allowedTCPPorts = harden [ ];
    allowedUDPPorts = harden [ ];
  };

  # defaultPackages is perl, rsync, strace. Sub-switches only:
  # documentation.enable is the master gate and takes man pages too.
  environment.defaultPackages = harden [ ];
  environment.stub-ld.enable = harden false;
  documentation.nixos.enable = harden false;
  documentation.info.enable = harden false;
  documentation.doc.enable = harden false;

  # Puts akonadi and kdepim-runtime on PATH — IMAP/EWS/Google/Kolab/DAV
  # agents with no mail client to use them.
  programs.kde-pim.enable = harden false;

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    krdp # second RDP server, next to xrdp
    plasma-browser-integration # native messaging host into the browser
    ffmpegthumbs # thumbnails by parsing whatever is in the directory
    elisa
    khelpcenter
    plasma-workspace-wallpapers
    plasma-keyboard
    qtvirtualkeyboard
  ];

  # Only geoclue2 and fwupd change anything; the rest are already off
  # and named so intent survives an upstream flip.
  services.geoclue2.enable = harden false;
  services.fwupd.enable = harden false;
  services.avahi.enable = harden false;
  services.printing.enable = harden false;
  services.gvfs.enable = harden false;
  services.blueman.enable = harden false;
  services.locate.enable = harden false;

  # Defaults to "*".
  nix.settings.allowed-users = harden [ "@wheel" ];

  security.protectKernelImage = harden true;

  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = harden 1;
    "kernel.kptr_restrict" = harden 2;
    "kernel.kexec_load_disabled" = harden 1;
    "kernel.unprivileged_bpf_disabled" = harden 1;
    "net.core.bpf_jit_harden" = harden 2;
    # Children only; attaching to a live PID needs root.
    "kernel.yama.ptrace_scope" = harden 1;
    "net.ipv4.conf.all.accept_source_route" = harden 0;
    "net.ipv4.conf.all.accept_redirects" = harden 0;
    "net.ipv4.conf.all.send_redirects" = harden 0;
    "net.ipv6.conf.all.accept_redirects" = harden 0;
    "net.ipv4.tcp_syncookies" = harden 1;
  };

  # squashfs and usb-storage stay: live ISO, removable media.
  boot.blacklistedKernelModules = [
    "dccp"
    "sctp"
    "rds"
    "tipc"
    "n-hdlc"
    "ax25"
    "netrom"
    "rose"
    "can"
    "atm"
    "appletalk"
    "psnap"
    "p8023"
    "p8022"
    "cramfs"
    "freevxfs"
    "jffs2"
    "hfs"
    "hfsplus"
  ];

}
