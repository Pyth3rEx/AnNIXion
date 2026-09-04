{
  pkgs,
  ctx,
  tunnelList,
  detectTunnel,
}:
let
  inherit (ctx) cfg helpGuard;
in
# ── Status helper ─────────────────────────────────────────────────────
pkgs.writeShellApplication {
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
}
