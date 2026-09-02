# ── VPN enforcement — kernel-level killswitch ────────────────────────────
# Enforced processes run in a persistent user slice; an nftables rule
# matches that cgroup and permits egress only through a live tunnel.
# Design and constraints: "VPN enforcement" in docs/usage.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.annixion.vpnEnforcement;

  sliceBare = lib.removeSuffix ".slice" cfg.sliceName;

  # systemd nests "-"-separated names: annixion-vpn.slice sits inside
  # annixion.slice, and the wrong depth matches nothing.
  sliceParts = lib.splitString "-" sliceBare;
  sliceSubPath = lib.concatStringsSep "/" (
    lib.imap1 (i: _: (lib.concatStringsSep "-" (lib.take i sliceParts)) + ".slice") sliceParts
  );

  # Path embeds the uid.
  cgroupPath = "user.slice/user-${toString cfg.uid}.slice/user@${toString cfg.uid}.service/${sliceSubPath}";
  cgroupFsPath = "/sys/fs/cgroup/${cgroupPath}";

  # Three user-manager levels plus one per name component.
  cgroupLevel = 3 + builtins.length sliceParts;

  dnsConfined = cfg.dnsServers != [ ];
  resolvArgs = lib.escapeShellArgs (map (s: "nameserver ${s}") cfg.dnsServers);

  # Only $1 is inspected, so a wrapped command's own -h still reaches it.
  helpGuard = text: ''
    case "''${1:-}" in
      -h | --help)
        printf '%s\n' ${lib.escapeShellArg text}
        exit 0
        ;;
    esac
  '';

  # ── Tunnel enumeration ────────────────────────────────────────────────
  # Read by both the detector and the loader, so they cannot disagree.
  tunnelList = pkgs.writeShellApplication {
    name = "annixion-vpn-tunnels";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.jq
    ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-tunnels

        Lists every interface that currently qualifies as a live VPN tunnel,
        one per line. An interface qualifies when it is up, is a tunnel
        device, and carries a route in some routing table.

          -h, --help  show this help
      ''}

            # Tunnels by construction, whatever they are named.
            tunnel_kinds="wireguard tun tap ppp vti vti6 xfrm ipip ip6tnl gre gretap sit wireguard-rs"

            is_tunnel_kind() {
              kind="$(ip -d -j link show dev "$1" 2>/dev/null \
                      | jq -r '.[0].linkinfo.info_kind // ""' 2>/dev/null || true)"
              [ -n "$kind" ] || return 1
              for k in $tunnel_kinds; do
                [ "$kind" = "$k" ] && return 0
              done
              return 1
            }

            # Fallback for tunnels of some other device type.
            matches_name() {
              case "$1" in
                ${lib.concatMapStringsSep "|" (i: i) cfg.tunnelInterfaces}) return 0 ;;
                *) return 1 ;;
              esac
            }

            # All tables: main alone is empty for wg-quick and Mullvad.
            has_route() {
              {
                ip route show table all dev "$1" 2>/dev/null
                ip -6 route show table all dev "$1" 2>/dev/null
              } | grep -vE '^(local|broadcast|multicast|unreachable|prohibit|blackhole)[[:space:]]' \
                | grep -vE '^fe80::/64[[:space:]]' \
                | grep -q .
            }

            for iface in $(ip -o link show up | awk -F': ' '{print $2}' | cut -d@ -f1); do
              [ "$iface" = "lo" ] && continue

              # This name reaches a root-built ruleset.
              case "$iface" in
                *[!A-Za-z0-9_.@-]*) continue ;;
              esac

              if is_tunnel_kind "$iface" || matches_name "$iface"; then
                has_route "$iface" && echo "$iface"
              fi
            done
    '';
  };

  # ── Tunnel detection ──────────────────────────────────────────────────
  detectTunnel = pkgs.writeShellApplication {
    name = "annixion-vpn-detect";
    runtimeInputs = [ tunnelList ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-detect

        Prints the first live tunnel interface, or exits 1 if none
        qualifies. annixion-vpn-tunnels lists them all.

          -h, --help  show this help
      ''}

            iface="$(annixion-vpn-tunnels | head -n 1)"
            [ -n "$iface" ] || exit 1
            echo "$iface"
    '';
  };

  # ── Privileged killswitch loader ──────────────────────────────────────
  # Argument-free by design: it is the one NOPASSWD command.
  killswitchLoad = pkgs.writeShellApplication {
    name = "annixion-vpn-killswitch-load";
    runtimeInputs = [
      pkgs.nftables
      pkgs.wireguard-tools
      tunnelList
    ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-killswitch-load

        Arms the nftables killswitch for the enforced slice. Needs root, a
        live tunnel, and the slice to exist already. Normally invoked by
        annixion-vpn-run rather than by hand.

          -h, --help  show this help
      ''}

            if [ ! -d "${cgroupFsPath}" ]; then
              echo "annixion-vpn-killswitch-load: cgroup ${cgroupFsPath} does not exist;" >&2
              echo "start ${cfg.sliceName} before loading the killswitch." >&2
              exit 1
            fi

            tunnels="$(annixion-vpn-tunnels)"
            if [ -z "$tunnels" ]; then
              echo "annixion-vpn-killswitch-load: no live tunnel interface found;" >&2
              echo "refusing to arm a killswitch that would permit nothing." >&2
              exit 1
            fi

            accepts=""
            while IFS= read -r iface; do
              [ -n "$iface" ] || continue
              accepts="$accepts    oifname \"$iface\" accept"$'\n'

              # The tunnel's own encapsulated packets, already encrypted.
              # `wg` fails on non-wg devices: userspace tunnels skip this.
              mark="$(wg show "$iface" fwmark 2>/dev/null || true)"
              if [ -n "$mark" ] && [ "$mark" != "off" ] && [ "$mark" != "0" ]; then
                accepts="$accepts    meta mark $mark accept"$'\n'
              fi

              # For setups that route the endpoint explicitly, unmarked.
              while IFS= read -r ep; do
                [ -n "$ep" ] || continue
                case "$ep" in
                  "(none)") continue ;;
                  \[*\]:*)
                    host="''${ep%%]:*}"; host="''${host#[}"
                    accepts="$accepts    ip6 daddr $host udp dport ''${ep##*]:} accept"$'\n'
                    ;;
                  *:*)
                    accepts="$accepts    ip daddr ''${ep%:*} udp dport ''${ep##*:} accept"$'\n'
                    ;;
                esac
              done <<< "$(wg show "$iface" endpoints 2>/dev/null | cut -f2 || true)"
            done <<< "$tunnels"

            rules="$(mktemp)"
            trap 'rm -f "$rules"' EXIT

            # printf, not a heredoc: the terminator's indentation depends
            # on how Nix strips this string.
            #
            # `table` + `delete table` makes the load idempotent. Loopback
            # DNS is rejected — a local resolver would forward it from
            # outside the cgroup. Reject, not drop, so leaks fail fast.
            {
              printf 'table inet annixion_vpn_killswitch\n'
              printf 'delete table inet annixion_vpn_killswitch\n\n'
              printf 'table inet annixion_vpn_killswitch {\n'
              printf '  chain output {\n'
              printf '    type filter hook output priority filter - 10; policy accept;\n'
              printf '    socket cgroupv2 level %s "%s" jump enforced\n' \
                '${toString cgroupLevel}' '${cgroupPath}'
              printf '  }\n\n'
              printf '  chain enforced {\n'
              printf '    oifname "lo" udp dport 53 reject with icmpx type admin-prohibited\n'
              printf '    oifname "lo" tcp dport 53 reject with icmpx type admin-prohibited\n'
              printf '    oifname "lo" accept\n'
              printf '%s' "$accepts"
              printf '    counter reject with icmpx type admin-prohibited\n'
              printf '  }\n'
              printf '}\n'
            } > "$rules"

            nft -f "$rules"
    '';
  };

  # ── Generic launcher ──────────────────────────────────────────────────
  # Any command, not just browsers: behind an intercepting proxy it is
  # Burp that makes the real requests, so it belongs in the slice too.
  vpnRun = pkgs.writeShellApplication {
    name = "annixion-vpn-run";
    runtimeInputs = [
      pkgs.systemd
      pkgs.kdePackages.kdialog
      detectTunnel
    ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-run <command> [args...]

        Runs a command inside the VPN-enforced slice. Refuses to start
        unless a tunnel is up, arms the killswitch, and confines the
        command's DNS to the tunnel.

          -h, --help  show this help
      ''}

            if [ $# -lt 1 ]; then
              echo "usage: annixion-vpn-run <command> [args...]" >&2
              exit 64
            fi

            # Label for the failure dialog.
            LABEL="''${ANNIXION_VPN_PROFILE:-$(basename "$1")}"
            export ANNIXION_VPN_PROFILE="$LABEL"

            fail() {
              MSG="$(${cfg.errorMessageCommand} 2>/dev/null || echo "$1")"
              kdialog --title "${cfg.errorTitle}" --error "$MSG" 2>/dev/null || true
              echo "annixion-vpn-run: $1" >&2
              exit 1
            }

            # 1. Fail before a window exists.
            if ! IFACE="$(annixion-vpn-detect)"; then
              fail "refusing to launch '$LABEL' — no VPN tunnel is up"
            fi
            export ANNIXION_VPN_IFACE="$IFACE"

            # 2. Slice before ruleset — nft needs the cgroup to exist.
            systemctl --user start ${cfg.sliceName}

            # 3. If arming fails, nothing starts.
            if ! sudo -n ${killswitchLoad}/bin/annixion-vpn-killswitch-load; then
              fail "refusing to launch '$LABEL' — could not arm the VPN killswitch"
            fi

            # 4. glibc hands lookups to nscd, outside this cgroup.
            ${lib.optionalString dnsConfined ''
              RESOLV_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/annixion-vpn"
              mkdir -p "$RESOLV_DIR"
              printf '%s\n' ${resolvArgs} > "$RESOLV_DIR/resolv.conf"
            ''}

            # 5. The killswitch keeps this honest if the tunnel drops.
            UNIT="annixion-vpn-$(basename "$1" | tr -cd '[:alnum:]_.-')-$$"
            exec systemd-run --user --quiet \
              --slice=${sliceBare} \
              --scope --unit="$UNIT" \
              ${lib.optionalString dnsConfined ''
                ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
                --ro-bind "$RESOLV_DIR/resolv.conf" /etc/resolv.conf \
                --tmpfs /run/nscd -- \
              ''}"$@"
    '';
  };

  # ── Browser launcher ──────────────────────────────────────────────────
  vpnBrowser = pkgs.writeShellApplication {
    name = "annixion-vpn-browser";
    runtimeInputs = [ vpnRun ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-browser <firefox-profile-name> [args...]

        Launches a Firefox profile inside the VPN-enforced slice, through
        annixion-vpn-run.

          -h, --help  show this help
      ''}

            if [ $# -lt 1 ]; then
              echo "usage: annixion-vpn-browser <firefox-profile-name> [args...]" >&2
              exit 64
            fi
            PROFILE="$1"; shift
            export ANNIXION_VPN_PROFILE="$PROFILE"

            exec annixion-vpn-run \
              ${cfg.browserPackage}/bin/firefox -P "$PROFILE" --no-remote "$@"
    '';
  };

  # ── Status helper ─────────────────────────────────────────────────────
  vpnStatus = pkgs.writeShellApplication {
    name = "annixion-vpn-status";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.nftables
      detectTunnel
      tunnelList
    ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-status

        Reports the live tunnels, whether the killswitch is armed, and
        whether the enforced slice is active. Exits 1 when no tunnel is up.

          -h, --help  show this help
      ''}

            RC=0
            if IFACE="$(annixion-vpn-detect)"; then
              # All of them — showing one would misreport the boundary.
              echo "tunnel:     live — $(annixion-vpn-tunnels | tr '\n' ' ')"
              ip -brief addr show dev "$IFACE"
            else
              echo "tunnel:     NONE — enforced browsers will refuse to launch"
              RC=1
            fi

            if sudo -n ${pkgs.nftables}/bin/nft list table inet annixion_vpn_killswitch \
                 > /dev/null 2>&1; then
              echo "killswitch: armed"
            else
              echo "killswitch: not loaded (armed on next enforced browser launch)"
            fi

            if systemctl --user is-active --quiet ${cfg.sliceName}; then
              echo "slice:      ${cfg.sliceName} active"
            else
              echo "slice:      ${cfg.sliceName} inactive"
            fi
            exit "$RC"
    '';
  };
in
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

    tunnelsPackage = lib.mkOption {
      type = lib.types.package;
      internal = true;
      readOnly = true;
      default = tunnelList;
      description = ''
        The tunnel enumerator, exposed so another module asks this one what
        counts as a live tunnel instead of deciding for itself.
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
