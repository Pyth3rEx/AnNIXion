# VPN enforcement — kernel-level killswitch.
# Enforced processes run in a persistent user slice; an nftables rule matches
# that cgroup and permits egress only through a live tunnel.
# Design and constraints: "VPN enforcement" in docs/usage.md.
#
# The programs are wired here rather than each importing the next, so the
# dependency order is visible in one place:
#   tunnels -> detect -> run -> browser
#   tunnels -> killswitch
#   tunnels, detect -> status
{
  config,
  lib,
  pkgs,
  ...
}:

let
  ctx = import ./context.nix { inherit config lib; };
  inherit (ctx) cfg sliceBare;

  tunnelList = import ./cli/tunnels.nix { inherit pkgs lib ctx; };
  detectTunnel = import ./cli/detect.nix { inherit pkgs ctx tunnelList; };
  killswitchLoad = import ./killswitch.nix { inherit pkgs ctx tunnelList; };
  vpnRun = import ./cli/run.nix {
    inherit
      pkgs
      lib
      ctx
      detectTunnel
      killswitchLoad
      ;
  };
  vpnBrowser = import ./cli/browser.nix { inherit pkgs ctx vpnRun; };
  vpnStatus = import ./cli/status.nix {
    inherit
      pkgs
      ctx
      tunnelList
      detectTunnel
      ;
  };
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    # NixOS still defaults to iptables; the killswitch needs nftables.
    networking.nftables.enable = lib.mkDefault true;

    # Persistent slice — the cgroup the nftables rule matches.
    systemd.user.slices.${sliceBare} = {
      description = "AnNIXion VPN-enforced applications";
      # No IPAddressDeny/Allow: those filter on destination, and
      # tunnelled traffic is bound for public addresses.
    };

    # Arming needs root; NOPASSWD is scoped to that one script.
    security.sudo.extraRules = [
      {
        users = [ config.users.users.operator.name ];
        commands = [
          {
            command = "${killswitchLoad}/bin/annixion-vpn-killswitch-load";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.nftables}/bin/nft list table inet annixion_vpn_killswitch";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    environment.systemPackages = [
      vpnRun
      vpnBrowser
      vpnStatus
      detectTunnel
      tunnelList
      killswitchLoad
    ];
  };
}
