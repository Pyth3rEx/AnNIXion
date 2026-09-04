{
  pkgs,
  lib,
  ctx,
  detectTunnel,
  killswitchLoad,
}:
let
  inherit (ctx)
    cfg
    sliceBare
    dnsConfined
    resolvArgs
    helpGuard
    ;
in
# ── Generic launcher ──────────────────────────────────────────────────
# Any command, not just browsers: behind an intercepting proxy it is
# Burp that makes the real requests, so it belongs in the slice too.
pkgs.writeShellApplication {
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
}
