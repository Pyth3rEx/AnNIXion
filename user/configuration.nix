# user/configuration.nix
# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM-LEVEL OVERRIDES
#
# Put your personal system settings here. This file is imported by flake.nix
# AFTER all base modules, so anything you write here wins automatically.
#
# You do NOT need lib.mkForce. Every option in the base modules uses
# lib.mkDefault (priority 1000). Your options here have normal priority (100),
# which is higher — they win without any special wrapper.
#
# ── What belongs here ────────────────────────────────────────────────────────
#   • Your hostname, timezone, locale
#   • Extra users or groups
#   • Extra system packages you want installed globally
#   • Swapping out or disabling base features (e.g. disable openssh)
#   • Any NixOS option from the manual: https://nixos.org/manual/nixos/stable/options
#
# ── What does NOT belong here ────────────────────────────────────────────────
#   • Your dotfiles, shell config, personal apps → those go in user/home.nix
#   • hardware-configuration.nix settings → edit that file directly
#
# ── Example overrides ────────────────────────────────────────────────────────
#
#   # Change hostname
#   networking.hostName = "my-machine";
#
#   # Change timezone
#   time.timeZone = "America/New_York";
#
#   # Add a package system-wide
#   environment.systemPackages = with pkgs; [ tcpdump ];
#
#   # Docker ships rootless. Switch to a root daemon only if a container
#   # needs the host network or a raw socket — it also puts you in the
#   # docker group, which is root-equivalent. See docs/hardening.md.
#   annixion.docker.rootless = false;
#
#   # Offensive work needs inbound callbacks (reverse shells, responder) on the
#   # engagement VPN, which the base firewall drops. Opt in to install the toggle,
#   # then arm per session: `annixion-offensive on` (off / status). Boots hardened.
#   # Add your tunnel's interface if it isn't tun0. See docs/hardening.md.
#   annixion.offensiveNet.enable = true;
#   # annixion.offensiveNet.trustedInterfaces = [ "tun0" "wg0" ];
#
#   # KWin composites through llvmpipe on a guest with no render node, which
#   # costs about three quarters of a core. Turn it on where there is real
#   # acceleration — "ls /dev/dri/renderD*" finds a node. See
#   # docs/customization.md.
#   annixion.desktop.compositing = true;
#
#   # The reporting platform runs locally and keeps client findings, so it
#   # binds loopback and encrypts at rest. The Hack The Box designs are
#   # imported on first start; add "offsec" for the OSCP set. Making it
#   # network-accessible publishes every engagement's deliverables over plain
#   # HTTP — read docs/sysreptor.md before you do.
#   # The login is created on first start from the hash below — mint one with
#   # `sysreptor hash`. The default is the shipped operator password, so it is
#   # public: change it here or in the UI. There is no login-less mode; every
#   # way to skip the login screen is Professional-edition only.
#   annixion.sysreptor = {
#     user = "operator";
#     hashedPassword = "pbkdf2_sha256$600000$...";
#     designs = [ "htb" "offsec" ];
#     # networkAccessible = true;
#     # allowedHosts = [ "reports.engagement.local" ];
#   };
#
#   # wpa_supplicant runs for the whole uptime even with no radio, because
#   # NetworkManager turns wireless on unconditionally. Turn it back on
#   # where there is one — "ls /sys/class/ieee80211" finds it. See
#   # docs/customization.md.
#   annixion.hardware.wireless = true;
#
#   # Disable SSH if you don't need the fallback
#   services.openssh.enable = false;
#
# ─────────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Your overrides go here.

  # Polkit rule: allow wheel group to power off and reboot without a password prompt.
  # Without this, shutdown/reboot from the KDE session silently fails.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
        action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions"
      ) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      }
    });
  '';

  imports = [
    # ./examples/hackthebox.nix # HTB Networking & DNS helper for AnNIXion
  ];
}
