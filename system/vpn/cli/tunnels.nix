{
  pkgs,
  lib,
  ctx,
}:
let
  inherit (ctx) cfg helpGuard;
in
# ── Tunnel enumeration ────────────────────────────────────────────────
# Read by both the detector and the loader, so they cannot disagree.
pkgs.writeShellApplication {
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
}
