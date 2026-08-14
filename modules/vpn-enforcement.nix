{
  config,
  lib,
  pkgs,
  ...
}:

# ============================================================
# VPN ENFORCEMENT — KERNEL-LEVEL KILLSWITCH
# ============================================================
# Confines browser profiles, and anything acting on their behalf, to the
# VPN tunnel in the kernel rather than in Firefox preferences. Prefs miss
# WebRTC, OCSP and captive-portal probes, and fall back to the default
# route in the clear when the tunnel drops.
#
#   1. A persistent user slice holds every enforced process.
#   2. An nftables table matches that cgroup on the output hook and
#      permits egress only through a live tunnel. With no tunnel, no
#      accept rule matches.
#   3. annixion-vpn-run refuses to launch without a tunnel, arms the
#      killswitch, then execs into the slice.
#
# Constraints to know before editing:
#   * nft resolves the cgroup path to an inode at load time, so the
#     slice must exist first and stay persistent. The launcher arms the
#     ruleset; boot cannot.
#   * nft matches oifname, not device type, and takes no wildcards in a
#     set. The loader enumerates live tunnels and emits one literal
#     accept each, making the ruleset a snapshot taken at arm time.
#   * Tunnels are found by device type plus a route in any table. Name
#     globs miss vendor naming (Mullvad ships ee-tll-wg-001), and the
#     main table is empty for wg-quick and Mullvad tunnels.
#   * WireGuard's encapsulated packets keep the inner packet's socket,
#     so the cgroup match catches them on the physical interface. They
#     must be accepted or the tunnel cannot transmit at all.
#   * glibc delegates lookups to nscd, which runs outside the cgroup.
#     The launcher masks its socket and supplies a tunnel-only resolver.
# ============================================================

let
  cfg = config.annixion.vpnEnforcement;

  sliceBare = lib.removeSuffix ".slice" cfg.sliceName;

  # systemd nests "-"-separated slice names: annixion-vpn.slice lives at
  # annixion.slice/annixion-vpn.slice. Derived, not hardcoded — getting
  # the depth wrong matches nothing and enforces nothing, silently.
  sliceParts = lib.splitString "-" sliceBare;
  sliceSubPath = lib.concatStringsSep "/" (
    lib.imap1 (i: _: (lib.concatStringsSep "-" (lib.take i sliceParts)) + ".slice") sliceParts
  );

  # nft matches the cgroup by path, which embeds the uid.
  cgroupPath = "user.slice/user-${toString cfg.uid}.slice/user@${toString cfg.uid}.service/${sliceSubPath}";
  cgroupFsPath = "/sys/fs/cgroup/${cgroupPath}";

  # Three user-manager levels, plus one per slice-name component.
  cgroupLevel = 3 + builtins.length sliceParts;

  dnsConfined = cfg.dnsServers != [ ];
  resolvArgs = lib.escapeShellArgs (map (s: "nameserver ${s}") cfg.dnsServers);

  # ── Tunnel enumeration ────────────────────────────────────────────────
  # Read by both the detector and the killswitch loader, so the launcher
  # can never permit a tunnel the ruleset does not. An interface must be
  # up, a tunnel, and carrying a route; one that routes nothing would
  # pass detection and then be blocked, reading as a blackhole.
  tunnelList = pkgs.writeShellApplication {
    name = "annixion-vpn-tunnels";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.jq
    ];
    text = ''
      # Kinds that are tunnels by construction, whatever they are named.
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

      # Fallback for tunnels presenting as some other device type.
      matches_name() {
        case "$1" in
          ${lib.concatMapStringsSep "|" (i: i) cfg.tunnelInterfaces}) return 0 ;;
          *) return 1 ;;
        esac
      }

      # All tables, both families: main alone is empty for a healthy
      # wg-quick or Mullvad tunnel. Link-local scaffolding is filtered
      # out, since every up interface has it.
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

        # These names reach a root-built nft ruleset. Creating a device
        # needs CAP_NET_ADMIN, so this is not a privilege boundary, but
        # an unquotable name is never legitimate.
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
  # Prints the first live tunnel interface, or exits 1.
  detectTunnel = pkgs.writeShellApplication {
    name = "annixion-vpn-detect";
    runtimeInputs = [ tunnelList ];
    text = ''
      iface="$(annixion-vpn-tunnels | head -n 1)"
      [ -n "$iface" ] || exit 1
      echo "$iface"
    '';
  };

  # ── Privileged killswitch loader ──────────────────────────────────────
  # Argument-free: this is the only command granted NOPASSWD, so it
  # derives the tunnel names itself rather than taking them from the
  # caller.
  killswitchLoad = pkgs.writeShellApplication {
    name = "annixion-vpn-killswitch-load";
    runtimeInputs = [
      pkgs.nftables
      pkgs.wireguard-tools
      tunnelList
    ];
    text = ''
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

        # The tunnel's own encapsulated packets (see header). Already
        # encrypted, and forging the mark needs CAP_NET_ADMIN, so this is
        # no escape route. `wg` fails on non-WireGuard devices, which is
        # how userspace tunnels skip it.
        mark="$(wg show "$iface" fwmark 2>/dev/null || true)"
        if [ -n "$mark" ] && [ "$mark" != "off" ] && [ "$mark" != "0" ]; then
          accepts="$accepts    meta mark $mark accept"$'\n'
        fi

        # Fallback for a setup that routes its endpoint explicitly
        # instead of by mark, leaving the outer packets unmarked.
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

      # `table` + `delete table` makes loading idempotent.
      cat > "$rules" <<EOF
      table inet annixion_vpn_killswitch
      delete table inet annixion_vpn_killswitch

      table inet annixion_vpn_killswitch {
        chain output {
          # Ahead of the main firewall chain, so the verdict lands first.
          type filter hook output priority filter - 10; policy accept;

          socket cgroupv2 level ${toString cgroupLevel} "${cgroupPath}" jump enforced
        }

        chain enforced {
          # Loopback stays reachable for local IPC and an intercepting
          # proxy, but not for DNS: a local resolver would forward the
          # query from outside this cgroup.
          oifname "lo" udp dport 53 reject with icmpx type admin-prohibited
          oifname "lo" tcp dport 53 reject with icmpx type admin-prohibited
          oifname "lo" accept

          # The only ways out, as they exist right now.
      $accepts
          # Reject, not drop: a leak attempt fails fast and visibly.
          counter reject with icmpx type admin-prohibited
        }
      }
      EOF

      nft -f "$rules"
    '';
  };

  # ── Generic launcher ──────────────────────────────────────────────────
  # Runs any command inside the enforced slice. Not just browsers: behind
  # an intercepting proxy the browser only reaches loopback and the proxy
  # makes the real requests, so Burp has to be in the slice too.
  vpnRun = pkgs.writeShellApplication {
    name = "annixion-vpn-run";
    runtimeInputs = [
      pkgs.systemd
      pkgs.kdePackages.kdialog
      detectTunnel
    ];
    text = ''
      if [ $# -lt 1 ]; then
        echo "usage: annixion-vpn-run <command> [args...]" >&2
        exit 64
      fi

      # Failure-message label: caller's name if set, else the command.
      LABEL="''${ANNIXION_VPN_PROFILE:-$(basename "$1")}"
      export ANNIXION_VPN_PROFILE="$LABEL"

      fail() {
        MSG="$(${cfg.errorMessageCommand} 2>/dev/null || echo "$1")"
        kdialog --title "${cfg.errorTitle}" --error "$MSG" 2>/dev/null || true
        echo "annixion-vpn-run: $1" >&2
        exit 1
      }

      # 1. Fail before any window exists, so nothing can be typed into a
      #    persona site on a naked connection.
      if ! IFACE="$(annixion-vpn-detect)"; then
        fail "refusing to launch '$LABEL' — no VPN tunnel is up"
      fi
      export ANNIXION_VPN_IFACE="$IFACE"

      # 2. Slice before ruleset: nft resolves the cgroup to an inode at
      #    load time, so it has to exist already.
      systemctl --user start ${cfg.sliceName}

      # 3. If arming fails nothing may start; an unenforced persona
      #    browser is the case being prevented.
      if ! sudo -n ${killswitchLoad}/bin/annixion-vpn-killswitch-load; then
        fail "refusing to launch '$LABEL' — could not arm the VPN killswitch"
      fi

      # 4. Confine DNS. glibc hands lookups to nscd, which runs outside
      #    this cgroup, so queries would keep resolving in the clear
      #    after the tunnel dropped. Masking its socket forces the
      #    process to resolve for itself, through the tunnel.
      ${lib.optionalString dnsConfined ''
        RESOLV_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/annixion-vpn"
        mkdir -p "$RESOLV_DIR"
        printf '%s\n' ${resolvArgs} > "$RESOLV_DIR/resolv.conf"
      ''}

      # 5. The killswitch is what keeps this honest if the tunnel drops
      #    mid-session.
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
      RC=0
      if IFACE="$(annixion-vpn-detect)"; then
        # All of them: the killswitch permits every live tunnel, so
        # showing one would misreport the boundary.
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
        nftables rule matches, so it must be the real uid of the desktop
        user or the killswitch matches nothing.
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
        Extra interface name patterns to treat as VPN tunnels.

        Tunnels are normally identified by device type (wireguard, tun,
        tap, ppp, xfrm, ...), so these are only needed for a tunnel
        presenting as some other type. An unrecognised tunnel fails
        closed.
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
        /etc/resolv.conf. They must be reachable only through the tunnel,
        so lookups fail closed with everything else.

        Unfiltered Quad9 by default, matching the Red Team and OSINT
        profiles: a blocklist would hide the infrastructure those tools
        exist to reach.

        Set to [ ] to leave DNS alone. Queries then go through nscd,
        outside the cgroup, and resolve in the clear once the tunnel is
        gone.
      '';
    };

    browserPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.firefox;
      description = ''
        Browser package the launcher execs. Must be the wrapped package
        carrying distribution/policies.json — under Home Manager that is
        programs.firefox.finalPackage, which flake.nix wires in.

        Bare pkgs.firefox has an empty policy set and fails silently: the
        browser opens with no certificate trust, no ExtensionSettings and
        no 3rdparty config.
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
    # The killswitch is nftables, so the backend must be too; NixOS
    # still defaults to iptables.
    networking.nftables.enable = lib.mkDefault true;

    # Persistent slice: enforced processes launch into it and the
    # nftables rule matches this cgroup.
    systemd.user.slices.${sliceBare} = {
      description = "AnNIXion VPN-enforced applications";
      # No IPAddressDeny/Allow: those filter on destination, and
      # tunnelled traffic is bound for public addresses. Interface-level
      # enforcement is the nftables rule's job.
    };

    # Arming needs root. Scope NOPASSWD to that one argument-free
    # script and nothing else.
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
