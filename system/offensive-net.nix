# ── Offensive networking — runtime inbound/MITM toggle ───────────────────
# The base firewall drops inbound, which kills reverse-shell callbacks; the
# hardening sysctls block redirect/MITM. This ships a runtime toggle that
# opens the engagement VPN interface and relaxes those sysctls, armed per
# session and gone on reboot. Off by default; arm with `annixion-offensive on`.
# What it opens and the firewall-reload caveat: docs/hardening.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.annixion.offensiveNet;

  ifaceArgs = lib.escapeShellArgs cfg.trustedInterfaces;
  ifaceList = lib.concatStringsSep " " cfg.trustedInterfaces;

  redirectSysctls = {
    "net.ipv4.conf.all.accept_redirects" = true;
    "net.ipv4.conf.all.send_redirects" = true;
    "net.ipv4.conf.all.accept_source_route" = true;
    "net.ipv6.conf.all.accept_redirects" = true;
  };
  setSysctls =
    v:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (k: _: "sysctl -wq ${k}=${toString v}") redirectSysctls
    );

  arm = pkgs.writeShellApplication {
    name = "annixion-offensive-arm";
    runtimeInputs = [
      pkgs.nftables
      pkgs.gnugrep
      pkgs.procps
    ];
    text = ''
      if ! nft list chain inet nixos-fw input > /dev/null 2>&1; then
        echo "annixion-offensive: nixos-fw input chain not found;" >&2
        echo "the nftables firewall must be enabled to arm." >&2
        exit 1
      fi

      # shellcheck disable=SC2043  # trustedInterfaces may hold a single entry
      for iface in ${ifaceArgs}; do
        if ! nft list chain inet nixos-fw input \
             | grep -qF "iifname \"$iface\" accept comment \"annixion-offensive\""; then
          nft insert rule inet nixos-fw input iifname "$iface" accept comment annixion-offensive
        fi
      done
      ${lib.optionalString cfg.relaxRedirects (setSysctls 1)}
    '';
  };

  disarm = pkgs.writeShellApplication {
    name = "annixion-offensive-disarm";
    runtimeInputs = [
      pkgs.nftables
      pkgs.gnugrep
      pkgs.procps
    ];
    text = ''
      while read -r _ h; do
        [ -n "$h" ] || continue
        nft delete rule inet nixos-fw input handle "$h"
      done <<< "$(nft -a list chain inet nixos-fw input 2>/dev/null \
        | grep -F 'comment "annixion-offensive"' \
        | grep -oE 'handle [0-9]+' || true)"
      ${lib.optionalString cfg.relaxRedirects (setSysctls 0)}
    '';
  };

  cli = pkgs.writeShellApplication {
    name = "annixion-offensive";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      unit=annixion-offensive.service
      case "''${1:-}" in
        on)  exec systemctl start "$unit" ;;
        off) exec systemctl stop  "$unit" ;;
        status)
          echo "offensive-net: $(systemctl is-active "$unit")"
          echo "interfaces:    ${ifaceList}"
          for k in net.ipv4.conf.all.accept_redirects \
                   net.ipv4.conf.all.send_redirects \
                   net.ipv4.conf.all.accept_source_route; do
            p="/proc/sys/''${k//.//}"
            echo "$k = $(cat "$p" 2>/dev/null || echo '?')"
          done
          ;;
        -h | --help | "")
          printf '%s\n' 'usage: annixion-offensive {on|off|status}

      Toggle the offensive networking posture at runtime. "on" opens inbound
      on the VPN interface(s) and relaxes redirect/MITM sysctls; "off" (and a
      reboot) restores the hardened posture.

        on      arm
        off     disarm
        status  show whether armed, the interfaces, and the live sysctls'
          [ "''${1:-}" = "" ] && exit 1
          exit 0
          ;;
        *)
          echo "annixion-offensive: unknown command ''${1}" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.annixion.offensiveNet = {
    enable = lib.mkEnableOption "runtime-togglable offensive networking (inbound callbacks and MITM/pivot)";

    trustedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tun0" ];
      example = [
        "tun0"
        "wg0"
      ];
      description = ''
        Interfaces whose inbound traffic the firewall accepts while armed —
        where reverse shells, `responder`, and payload-delivery listeners
        receive their callbacks. Defaults to `tun0`, the OpenVPN name HTB and
        most engagements use; add the engagement's own tunnel when it differs.

        Trusting an interface that is not up is a no-op, so this is safe to
        leave set off-engagement. Only inbound on these interfaces is opened;
        the real NICs stay closed.
      '';
    };

    relaxRedirects = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Also flip the ICMP-redirect and source-route sysctls that
        system/hardening.nix pins off, so ARP/ICMP-redirect MITM and pivoting
        work while armed. Disarming restores the hardened values.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The inbound accept must live in the native nixos-fw chain to be terminal
    # before its drop; that needs the nftables backend.
    networking.nftables.enable = lib.mkDefault true;

    environment.systemPackages = [ cli ];

    systemd.services.annixion-offensive = {
      description = "Offensive networking posture (inbound callbacks and MITM/pivot)";
      wantedBy = [ ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe arm;
        ExecStop = lib.getExe disarm;
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "annixion-offensive.service" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
