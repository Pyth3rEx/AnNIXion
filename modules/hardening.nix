{
  config,
  lib,
  pkgs,
  ...
}:

# ============================================================
# HARDENING — ATTACK SURFACE REDUCTION
# ============================================================
# Removes services, packages and kernel features the system does not
# need, so what is left is what AnNIXion actually uses.
#
# Everything here is set at priority 900. That beats an upstream
# lib.mkDefault (1000), which several of these carry, while still losing
# to a plain assignment in user/configuration.nix (100) — so restoring
# any of it is one line, no lib.mkForce required:
#
#   services.openssh.enable = true;
#
# What is deliberately NOT hardened, and why, is at the bottom. Read it
# before adding to this list: three of the obvious next steps break
# things AnNIXion depends on.
# ============================================================

let
  harden = lib.mkOverride 900;
in
{
  # ── Remote access ─────────────────────────────────────────────────
  # sshd was the only remotely reachable service, on 0.0.0.0:22 with
  # password authentication. xrdp reaches the desktop over vsock, and
  # the hypervisor console is the recovery path.
  services.openssh.enable = harden false;

  # ── Daemons with no hardware to serve ─────────────────────────────
  # ModemManager probes serial and USB devices; NetworkManager pulls it
  # in at mkDefault true whether or not a modem exists.
  networking.modemmanager.enable = harden false;
  services.power-profiles-daemon.enable = harden false;

  # Plasma turns the Orca screen reader on by default, which pulls in
  # speech-dispatcher and the at-spi2 accessibility bus — three daemons
  # for a feature most installs never use. This is an accessibility
  # feature, so it is called out rather than folded in silently: if you
  # need a screen reader, put this in user/configuration.nix and the
  # other two follow.
  #
  #   services.orca.enable = true;
  services.orca.enable = harden false;
  services.speechd.enable = harden false;

  # ── Firewall ──────────────────────────────────────────────────────
  # Nothing listens that should be reachable, so nothing is opened.
  # xrdp's openFirewall is switched off at its own module: Enhanced
  # Session arrives over vsock, so the TCP port was open with nothing
  # behind it.
  networking.firewall = {
    enable = harden true;
    allowedTCPPorts = harden [ ];
    allowedUDPPorts = harden [ ];
  };

  # ── Base packages and docs ────────────────────────────────────────
  # defaultPackages is perl, rsync and strace, none of which the system
  # needs to boot or run.
  #
  # Only the three sub-switches are set. documentation.enable is the
  # master gate and takes man pages with it -- 162 of them, dig and the
  # dnssec-* family included -- which is the wrong trade on a tooling
  # distro.
  environment.defaultPackages = harden [ ];
  environment.stub-ld.enable = harden false;
  documentation.nixos.enable = harden false;
  documentation.info.enable = harden false;
  documentation.doc.enable = harden false;

  # ── KDE PIM ───────────────────────────────────────────────────────
  # Plasma enables this at mkDefault true, putting akonadi and
  # kdepim-runtime on PATH: a database and a set of agents that speak
  # IMAP, EWS, Google, Kolab and DAV. No mail client is installed to use
  # any of it. kmail, kontact and merkuro are separate switches and were
  # already off.
  programs.kde-pim.enable = harden false;

  # ── Plasma optional packages ──────────────────────────────────────
  # Everything Plasma installs that this distro has no use for. konsole,
  # kate, dolphin, ark, okular, gwenview and spectacle are kept: the
  # panel launches some, the zsh config edits with kate, and the rest
  # are how you read what you collect.
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    # A second RDP server, alongside the xrdp this distro configures.
    krdp
    # Bridges the desktop to Chrome and Firefox through a native
    # messaging host. The browser profiles here are deliberately
    # locked down; this reaches around them.
    plasma-browser-integration
    # Generates thumbnails by parsing whatever video a directory
    # happens to contain.
    ffmpegthumbs
    elisa
    khelpcenter
    plasma-workspace-wallpapers
    plasma-keyboard
    qtvirtualkeyboard
  ];

  # ── Desktop services ──────────────────────────────────────────────
  # geoclue2 and fwupd are on by default and are the only two here that
  # change anything; the rest are already off and are named so the
  # intent survives an upstream default flipping.
  services.geoclue2.enable = harden false;
  services.fwupd.enable = harden false;
  services.avahi.enable = harden false;
  services.printing.enable = harden false;
  services.gvfs.enable = harden false;
  services.blueman.enable = harden false;
  services.locate.enable = harden false;

  # ── Nix daemon ────────────────────────────────────────────────────
  # allowed-users defaults to "*", letting any account submit builds.
  nix.settings.allowed-users = harden [ "@wheel" ];

  # ── Kernel ────────────────────────────────────────────────────────
  security.protectKernelImage = harden true;

  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = harden 1;
    "kernel.kptr_restrict" = harden 2;
    "kernel.kexec_load_disabled" = harden 1;
    "kernel.unprivileged_bpf_disabled" = harden 1;
    "net.core.bpf_jit_harden" = harden 2;
    # Debuggers still attach to their own children, so gdb ./target and
    # strace -f work; attaching to an unrelated live PID needs root.
    "kernel.yama.ptrace_scope" = harden 1;
    "net.ipv4.conf.all.accept_source_route" = harden 0;
    "net.ipv4.conf.all.accept_redirects" = harden 0;
    "net.ipv4.conf.all.send_redirects" = harden 0;
    "net.ipv6.conf.all.accept_redirects" = harden 0;
    "net.ipv4.tcp_syncookies" = harden 1;
  };

  # Protocols and filesystems nothing here speaks. squashfs and
  # usb-storage are excluded from this list on purpose — the live ISO
  # needs one and removable media needs the other.
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

  # ── Deliberately left alone ───────────────────────────────────────
  # security.lockKernelModules
  #   Blocks module loading after boot. `ip link add type wireguard`
  #   would fail, taking VPN enforcement with it.
  #
  # kernel.unprivileged_userns_clone = 0 / user.max_user_namespaces = 0
  #   The usual next hardening step, and it breaks two things AnNIXion
  #   relies on: bubblewrap, which annixion-vpn-run uses to confine DNS,
  #   and Firefox's own content sandbox.
  #
  # net.ipv4.conf.*.rp_filter = 1
  #   Strict reverse-path filtering drops the asymmetric paths that
  #   policy-routed WireGuard tunnels create.
  #
  # udisks2, upower, wireless, xdg.portal
  #   Plasma's device and battery integration, wifi on laptop installs,
  #   and the portal the GTK and Flatpak file choosers go through.
  #   Plasma sets udisks2 and xdg.portal at normal priority, so harden
  #   cannot touch them anyway -- it would take mkForce, and the result
  #   would be no USB mounting and a broken file chooser.
  #
  # polkit / pkexec
  #   Plasma needs polkit for privileged actions, and the control centre
  #   killswitch goes through it.
}
