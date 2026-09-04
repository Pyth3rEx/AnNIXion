{
  pkgs,
  ctx,
  tunnelList,
}:
let
  inherit (ctx)
    cfg
    cgroupPath
    cgroupFsPath
    cgroupLevel
    helpGuard
    ;
in
# ── Privileged killswitch loader ──────────────────────────────────────
# Argument-free by design: it is the one NOPASSWD command.
pkgs.writeShellApplication {
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
}
