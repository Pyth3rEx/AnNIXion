{
  pkgs,
  ctx,
  vpnRun,
}:
let
  inherit (ctx) cfg helpGuard;
in
# ── Browser launcher ──────────────────────────────────────────────────
pkgs.writeShellApplication {
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
}
