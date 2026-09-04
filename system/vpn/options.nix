# Every option the killswitch takes. Split from the module so the shape of
# the interface can be read without the implementation under it.
{ lib, pkgs, ... }:

{
  options.annixion.vpnEnforcement = {
    enable = lib.mkEnableOption "kernel-level VPN egress enforcement for browser profiles" // {
      default = true;
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        uid of the enforced account. Baked into the cgroup path the
        nftables rule matches, so it must be the desktop user's real uid
        or the killswitch matches nothing.
      '';
    };

    sliceName = lib.mkOption {
      type = lib.types.str;
      default = "annixion-vpn.slice";
      description = "Persistent user slice that enforced browsers run inside.";
    };

    tunnelInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "tun*"
        "tap*"
        "wg*"
        "proton*"
        "nordlynx"
        "mullvad*"
      ];
      description = ''
        Extra interface name patterns to treat as VPN tunnels. Tunnels are
        normally identified by device type (wireguard, tun, tap, ppp,
        xfrm, ...), so these are only needed for a tunnel presenting as
        some other type. An unrecognised tunnel fails closed.
      '';
    };

    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "9.9.9.10"
        "149.112.112.10"
      ];
      description = ''
        Resolvers for enforced processes, supplied as a private
        /etc/resolv.conf. Reachable only through the tunnel, so lookups
        fail closed with everything else. Unfiltered Quad9 by default: a
        blocklist would hide the infrastructure these tools exist to reach.

        Set to [ ] to leave DNS alone — queries then go through nscd,
        outside the cgroup, and resolve in the clear once the tunnel drops.
      '';
    };

    browserPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.firefox;
      description = ''
        Browser package the launcher execs. Must be the wrapped package
        carrying distribution/policies.json — under Home Manager that is
        programs.firefox.finalPackage, which flake.nix wires in. Bare
        pkgs.firefox fails silently: no certificate trust, no
        ExtensionSettings, no 3rdparty config.
      '';
    };

    errorTitle = lib.mkOption {
      type = lib.types.str;
      default = "VPN Required";
      description = "Title of the hard-fail dialog.";
    };

    errorMessageCommand = lib.mkOption {
      type = lib.types.str;
      default = toString (
        pkgs.writeShellScript "annixion-vpn-error" ''
          echo "No VPN tunnel is active."
          echo ""
          echo "The '${"$"}{ANNIXION_VPN_PROFILE}' profile is locked to the tunnel"
          echo "and will not open without one."
          echo ""
          echo "Connect your VPN, then launch it again."
        ''
      );
      description = ''
        Command whose stdout becomes the hard-fail message.
        ANNIXION_VPN_PROFILE is exported to it, holding the refused
        profile. For example:

          annixion.vpnEnforcement.errorMessageCommand =
            "''${pkgs.myMessageScript}/bin/msg";
      '';
    };
  };
}
