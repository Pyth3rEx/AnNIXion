{
  config,
  lib,
  pkgs,
  ...
}:

# ============================================================
# VPN ENFORCEMENT — KERNEL-LEVEL KILLSWITCH
# ============================================================
# Confines browser profiles — and anything making requests on their
# behalf — to the VPN tunnel in the kernel rather than in Firefox
# preferences. Prefs are a request, not a boundary: they miss WebRTC,
# OCSP and captive-portal probes, and when the tunnel drops the packets
# simply take the default route in the clear.
#
# How it works:
#   1. A persistent user slice, annixion-vpn.slice, holds every
#      enforced process.
#   2. An nftables table matches that cgroup on the output hook and
#      permits egress only through a live tunnel. Fail-closed by
#      construction: with no tunnel, no accept rule matches.
#   3. annixion-vpn-run refuses to launch without a tunnel, arms the
#      killswitch, then execs the command into the slice.
#
# Three constraints drive the shape:
#   * nft resolves a cgroup path to an inode when the ruleset is
#     loaded, so the slice must already exist and must be persistent —
#     hence the launcher arms the killswitch instead of doing it at
#     boot.
#   * nft can match oifname but not device type, and rejects wildcards
#     inside a set. The loader therefore enumerates live tunnels and
#     emits one literal accept per device, which makes the ruleset a
#     snapshot taken at arm time: a tunnel returning under a new name
#     stops traffic until the next launch.
#   * Tunnels are identified by device type, never by name — no glob
#     anticipates vendor naming like Mullvad's "ee-tll-wg-001". A route
#     in any table counts, since wg-quick and Mullvad install theirs in
#     a private table reached by an fwmark rule.
#   * glibc does not resolve names itself — it asks nscd, which runs
#     outside the enforced cgroup, so blocking DNS in the ruleset stops
#     only direct queries and nothing that ordinary software does. The
#     launcher masks the nscd socket and supplies a resolver reachable
#     only through the tunnel, which puts lookups back inside the
#     cgroup where the killswitch governs them.
#   * WireGuard encapsulates in the kernel and the outer packet keeps
#     the socket that produced the inner one, so the cgroup match
#     catches it — on the physical interface, since its fwmark routes
#     it around the tunnel table. It has to be accepted explicitly or
#     the tunnel cannot transmit for enforced processes at all, which
#     presents as a hang rather than a block.
# ============================================================

let
  cfg = config.annixion.vpnEnforcement;

  sliceBare = lib.removeSuffix ".slice" cfg.sliceName;

  # systemd treats "-" in a slice name as a hierarchy separator, so
  # annixion-vpn.slice is really nested inside annixion.slice:
  #   annixion-vpn.slice  →  annixion.slice/annixion-vpn.slice
  # Getting this wrong is silent: nft would match nothing and enforce
  # nothing, so the path is derived rather than hardcoded.
  sliceParts = lib.splitString "-" sliceBare;
  sliceSubPath = lib.concatStringsSep "/" (
    lib.imap1 (i: _: (lib.concatStringsSep "-" (lib.take i sliceParts)) + ".slice") sliceParts
  );

  # nft matches the cgroup by path, and that path contains the uid:
  #   user.slice/user-<uid>.slice/user@<uid>.service/<nested slice path>
  cgroupPath = "user.slice/user-${toString cfg.uid}.slice/user@${toString cfg.uid}.service/${sliceSubPath}";
  cgroupFsPath = "/sys/fs/cgroup/${cgroupPath}";

  # Depth of the leaf slice: the three user-manager levels above it, plus
  # one level per "-"-separated component of the slice name.
  cgroupLevel = 3 + builtins.length sliceParts;

  dnsConfined = cfg.dnsServers != [ ];
  resolvArgs = lib.escapeShellArgs (map (s: "nameserver ${s}") cfg.dnsServers);

  # ── Tunnel enumeration ────────────────────────────────────────────────
  # Single source of truth for "which interfaces are live tunnels", read
  # by both the detector and the killswitch loader so the launcher can
  # never permit a tunnel the ruleset does not.
  #
  # An interface qualifies only if it is up, is a tunnel, AND carries a
  # route: one that routes nothing would pass a naive check while the
  # killswitch correctly blocks it, which reads as an unexplained
  # blackhole.
  tunnelList = pkgs.writeShellApplication {
    name = "annixion-vpn-tunnels";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.jq
    ];
    text = ''
      # Link kinds that are tunnels by construction — a WireGuard device
      # is one whatever the vendor named it.
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

      # All tables, both families: the main table alone is empty for a
      # healthy wg-quick or Mullvad tunnel. Addresses and link-local
      # scaffolding are filtered out, since every up interface has them.
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

        # These names reach an nft ruleset built by a root script.
        # Creating a device needs CAP_NET_ADMIN so this is no privilege
        # boundary, but an unquotable name is never legitimate here.
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
  # Argument-free by design: this is the only command granted NOPASSWD,
  # so it derives the tunnel names itself rather than accepting anything
  # the caller controls.
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

        # Let the tunnel's own encapsulated packets out (see header).
        # They are already encrypted, and forging the mark needs
        # CAP_NET_ADMIN, so this is no escape route. `wg` fails on
        # non-WireGuard devices, which is how userspace tunnels skip it:
        # they encapsulate from their own process, outside this cgroup.
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

      # The `table` + `delete table` prelude makes loading idempotent:
      # create if absent, remove, then define fresh.
      cat > "$rules" <<EOF
      table inet annixion_vpn_killswitch
      delete table inet annixion_vpn_killswitch

      table inet annixion_vpn_killswitch {
        chain output {
          # Ahead of the main firewall output chain, so the verdict lands
          # before anything else can accept the packet.
          type filter hook output priority filter - 10; policy accept;

          socket cgroupv2 level ${toString cgroupLevel} "${cgroupPath}" jump enforced
        }

        chain enforced {
          # Loopback stays reachable for local IPC and an intercepting
          # proxy — but not for DNS, since a local resolver would forward
          # the query from outside this cgroup and escape enforcement.
          # Enforced profiles use DoH over the tunnel instead.
          oifname "lo" udp dport 53 reject with icmpx type admin-prohibited
          oifname "lo" tcp dport 53 reject with icmpx type admin-prohibited
          oifname "lo" accept

          # The only ways out, as they exist right now.
      $accepts
          # Reject rather than drop, so a leak attempt fails fast and
          # visibly instead of hanging.
          counter reject with icmpx type admin-prohibited
        }
      }
      EOF

      nft -f "$rules"
    '';
  };

  # ── Generic launcher ──────────────────────────────────────────────────
  # Runs ANY command inside the enforced slice. This matters beyond
  # browsers: with an intercepting proxy, the browser only ever talks to
  # loopback and the real egress is the proxy's. Enforcing the browser
  # alone would confine nothing — Burp has to be in the slice too.
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

      # Label used in the failure message: the caller's name if it set one
      # (annixion-vpn-browser passes the profile), else the command.
      LABEL="''${ANNIXION_VPN_PROFILE:-$(basename "$1")}"
      export ANNIXION_VPN_PROFILE="$LABEL"

      fail() {
        MSG="$(${cfg.errorMessageCommand} 2>/dev/null || echo "$1")"
        kdialog --title "${cfg.errorTitle}" --error "$MSG" 2>/dev/null || true
        echo "annixion-vpn-run: $1" >&2
        exit 1
      }

      # 1. Fail before any window exists, so there is no chance of typing
      #    into a persona site on a naked connection.
      if ! IFACE="$(annixion-vpn-detect)"; then
        fail "refusing to launch '$LABEL' — no VPN tunnel is up"
      fi
      export ANNIXION_VPN_IFACE="$IFACE"

      # 2. Slice before ruleset: nft resolves the cgroup path to an inode
      #    at load time, so the cgroup has to exist already.
      systemctl --user start ${cfg.sliceName}

      # 3. If arming fails, nothing may start — an unenforced persona
      #    browser is the whole thing being prevented.
      if ! sudo -n ${killswitchLoad}/bin/annixion-vpn-killswitch-load; then
        fail "refusing to launch '$LABEL' — could not arm the VPN killswitch"
      fi

      # 4. Confine DNS. glibc hands name lookups to nscd, which runs
      #    outside this cgroup, so an enforced process's queries are
      #    made by a daemon the killswitch never sees — they would carry
      #    on resolving in the clear after the tunnel dropped, leaking
      #    exactly the names the profile was visiting. Masking the nscd
      #    socket forces the process to resolve for itself, against a
      #    resolver reachable only through the tunnel, so DNS now fails
      #    closed with everything else.
      ${lib.optionalString dnsConfined ''
        RESOLV_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/annixion-vpn"
        mkdir -p "$RESOLV_DIR"
        printf '%s\n' ${resolvArgs} > "$RESOLV_DIR/resolv.conf"
      ''}

      # 5. The tunnel is up now; the killswitch is what keeps it honest
      #    if it drops mid-session.
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
        # All of them, not just the first: the killswitch permits every
        # live tunnel, so showing one would misreport the boundary.
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
        uid of the account whose slice is enforced. This is baked into the
        cgroup path the nftables rule matches, so it must be the real uid
        of the desktop user or the killswitch will match nothing.
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
        tap, ppp, xfrm, ...), so these patterns are only needed for a
        tunnel presenting as some other type. An unrecognised tunnel
        fails CLOSED (traffic blocked), never open.
      '';
    };

    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "9.9.9.10"
        "149.112.112.10"
      ];
      description = ''
        Resolvers that enforced processes use, given to them as a private
        /etc/resolv.conf. They must be reachable through the tunnel and
        nowhere else, so a lookup fails closed exactly like any other
        traffic when the tunnel drops.

        Unfiltered Quad9 by default, matching the Red Team and OSINT
        browser profiles: a blocklist would hide the infrastructure those
        tools exist to reach.

        Set to [ ] to leave DNS alone. Queries then go to the system
        resolver via nscd, which runs outside the enforced cgroup — the
        killswitch cannot see them, and they resolve in the clear once
        the tunnel is gone.
      '';
    };

    browserPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.firefox;
      description = ''
        Browser package the launcher execs.

        This must be the *wrapped* package carrying
        distribution/policies.json — under Home Manager that is
        programs.firefox.finalPackage, which flake.nix wires in. Bare
        pkgs.firefox has an empty policy set, and pointing the launcher
        at it fails silently: the browser opens, but with no certificate
        trust, no ExtensionSettings and no 3rdparty extension config.
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
        Command whose stdout becomes the hard-fail message. Override it to
        change the wording, or point it at a script for a message built at
        failure time. ANNIXION_VPN_PROFILE is exported for it, holding the
        profile that was refused. For example:

          annixion.vpnEnforcement.errorMessageCommand =
            "''${pkgs.myMessageScript}/bin/msg";
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The killswitch is nftables, so the firewall backend must be too.
    # NixOS still defaults to the iptables backend.
    networking.nftables.enable = lib.mkDefault true;

    # Persistent slice: enforced browsers are launched into it, and the
    # nftables rule matches this cgroup.
    systemd.user.slices.${sliceBare} = {
      description = "AnNIXion VPN-enforced applications";
      # Note: no IPAddressDeny/Allow. Those filter on *destination*
      # address, and tunnelled traffic is destined for public addresses —
      # denying by default would block exactly what we want to permit.
      # Interface-level enforcement is the nftables rule's job.
    };

    # The launcher arms the killswitch, which needs root. Scope the
    # NOPASSWD grant to that one argument-free script and nothing else.
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
