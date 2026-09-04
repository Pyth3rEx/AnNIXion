{
  pkgs,
  ctx,
  tunnelList,
}:
let
  inherit (ctx) helpGuard;
in
# ── Tunnel detection ──────────────────────────────────────────────────
pkgs.writeShellApplication {
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
}
