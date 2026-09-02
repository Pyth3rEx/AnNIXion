# ── VPN health — say so when the tunnel is not fit for work ──────────────
# A tunnel can be up, connected, and still useless: relays routinely answer
# port 53 themselves, and a route can leave by the wrong device. Neither
# reads as a disconnection, and both make recon lie. Design and constraints:
# "VPN health" in docs/usage.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.annixion.vpnHealth;

  # This module does not get its own opinion of what a tunnel is.
  tunnelList = config.annixion.vpnEnforcement.tunnelsPackage;

  # Only $1 is inspected, so a wrapped command's own -h still reaches it.
  helpGuard = text: ''
    case "''${1:-}" in
      -h | --help)
        printf '%s\n' ${lib.escapeShellArg text}
        exit 0
        ;;
    esac
  '';

  # ── The check ─────────────────────────────────────────────────────────
  vpnCheck = pkgs.writeShellApplication {
    name = "annixion-vpn-check";
    runtimeInputs = [
      pkgs.dnsutils
      pkgs.iproute2
      pkgs.gnugrep
      pkgs.gnused
      pkgs.coreutils
      tunnelList
    ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-check [--transfer]

        Checks that the live tunnel is fit for work, not merely up: that
        the internet leaves by it, that nothing on the path is answering
        port 53, and that names still resolve.

        Exit 0 healthy, 1 faulty, 2 no tunnel is up.

          --transfer  also attempt a real zone transfer (needs the network)
          -h, --help  show this help
      ''}

      TRANSFER=0
      for arg in "$@"; do
        case "$arg" in
          --transfer) TRANSFER=1 ;;
          *)
            echo "annixion-vpn-check: unknown argument '$arg'" >&2
            exit 64
            ;;
        esac
      done

      faults=0
      ok() { printf 'ok    %s\n' "$1"; }
      bad() {
        printf 'FAULT %s\n' "$1"
        faults=$((faults + 1))
      }

      TUNNELS="$(annixion-vpn-tunnels)"
      if [ -z "$TUNNELS" ]; then
        echo "annixion-vpn-check: no tunnel is up — nothing to check"
        exit 2
      fi
      ok "tunnel: $(printf '%s' "$TUNNELS" | tr '\n' ' ')"

      # ── Does the internet actually leave by the tunnel? ────────────────
      DEV="$(ip -o route get ${cfg.egressProbe} 2>/dev/null \
             | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -n 1)"
      if [ -z "$DEV" ]; then
        bad "egress: no route to ${cfg.egressProbe} at all"
      elif printf '%s\n' "$TUNNELS" | grep -qx "$DEV"; then
        ok "egress: ${cfg.egressProbe} leaves by $DEV"
      else
        bad "egress: ${cfg.egressProbe} leaves by $DEV, outside the tunnel"
      fi

      # ── Is somebody else answering port 53? ────────────────────────────
      # RFC 5737 TEST-NET-1 is routable to nothing, so nothing can answer
      # from it. A reply means every destination gets the same resolver,
      # and no query of ours reaches the nameserver it names.
      PROBE="$(dig +time=3 +tries=1 +short A example.com @192.0.2.1 2>/dev/null \
               | grep -v '^;' || true)"
      if [ -n "$PROBE" ]; then
        bad "dns: port 53 is intercepted — 192.0.2.1 answered ($(printf '%s' "$PROBE" | tr '\n' ' '))"
      else
        ok "dns: port 53 reaches the server it is addressed to"
      fi

      # ── Does anything resolve at all? ──────────────────────────────────
      if [ -n "$(dig +time=5 +tries=1 +short A example.com 2>/dev/null | grep -v '^;' || true)" ]; then
        ok "dns: the configured resolver answers"
      else
        bad "dns: the configured resolver answers nothing"
      fi

      # ── The thing an intercepted path silently breaks ──────────────────
      if [ "$TRANSFER" -eq 1 ]; then
        XFR="$(dig +time=8 +tries=1 +tcp axfr @${cfg.transferServer} ${cfg.transferZone} 2>&1 || true)"
        if printf '%s' "$XFR" | grep -q 'XFR size:'; then
          ok "axfr: ${cfg.transferZone} transferred from ${cfg.transferServer}"
        else
          bad "axfr: ${cfg.transferZone} would not transfer from ${cfg.transferServer}"
        fi
      fi

      echo
      if [ "$faults" -eq 0 ]; then
        echo "annixion-vpn-check: the tunnel is fit for work"
        exit 0
      fi

      echo "annixion-vpn-check: $faults fault(s) — this tunnel is up but not sound."
      echo "A relay that answers port 53 makes DNS recon lie: a zone transfer comes"
      echo "back 'Transfer failed.' as though the zone refused it, and every lookup"
      echo "is the relay's answer rather than the nameserver's. Traffic leaving"
      echo "outside the tunnel is a leak, whatever the client says it is doing."
      echo "Neither is fixable from this machine — change the provider's DNS"
      echo "setting, its server, or the provider."
      exit 1
    '';
  };

  # ── The yell ──────────────────────────────────────────────────────────
  defaultAlert = pkgs.writeShellScript "annixion-vpn-alert" ''
    REPORT="$(cat)"
    ${pkgs.kdePackages.kdialog}/bin/kdialog --title ${lib.escapeShellArg cfg.alertTitle} \
      --error "$REPORT" 2>/dev/null \
      || ${pkgs.libnotify}/bin/notify-send --urgency=critical \
           ${lib.escapeShellArg cfg.alertTitle} "$REPORT" 2>/dev/null \
      || true
  '';

  # ── The watcher ───────────────────────────────────────────────────────
  # Run by the timer. Yells on the tick a fault appears, stays quiet while
  # it persists, and exits with the verdict so the unit itself reads as
  # failed for as long as the tunnel is unsound.
  vpnWatch = pkgs.writeShellApplication {
    name = "annixion-vpn-watch";
    runtimeInputs = [
      pkgs.coreutils
      vpnCheck
    ];
    text = ''
      ${helpGuard ''
        usage: annixion-vpn-watch

        Runs annixion-vpn-check, prints the report, and raises the alert
        when a tunnel first goes faulty. Driven by annixion-vpn-watch.timer.

          -h, --help  show this help
      ''}

      STATE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/annixion-vpn-health.state"

      RC=0
      REPORT="$(annixion-vpn-check 2>&1)" || RC=$?
      printf '%s\n' "$REPORT"

      LAST="$(cat "$STATE" 2>/dev/null || echo none)"
      printf '%s\n' "$RC" > "$STATE"

      if [ "$RC" -eq 1 ] && [ "$LAST" != "1" ]; then
        printf '%s\n' "$REPORT" | ${cfg.alertCommand}
      fi

      exit "$RC"
    '';
  };
in
{
  options.annixion.vpnHealth = {
    enable = lib.mkEnableOption "checks that a live tunnel is fit for work" // {
      default = true;
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often the watcher re-checks a live tunnel.";
    };

    egressProbe = lib.mkOption {
      type = lib.types.str;
      default = "1.1.1.1";
      description = ''
        Address the egress check asks the kernel to route. Nothing is sent
        to it — only the device the route picks is read.
      '';
    };

    transferZone = lib.mkOption {
      type = lib.types.str;
      default = "zonetransfer.me";
      description = ''
        Zone the optional --transfer check asks for. The default is
        published to allow AXFR, so a refusal is this machine's path
        rather than the zone's policy.
      '';
    };

    transferServer = lib.mkOption {
      type = lib.types.str;
      default = "nsztm1.digi.ninja";
      description = "Nameserver the --transfer check asks for the zone.";
    };

    alertTitle = lib.mkOption {
      type = lib.types.str;
      default = "VPN faulty";
      description = "Title of the alert the watcher raises.";
    };

    alertCommand = lib.mkOption {
      type = lib.types.str;
      default = toString defaultAlert;
      description = ''
        Command the watcher pipes the report into when a tunnel goes
        faulty. The default raises a kdialog error, falling back to a
        critical desktop notification.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.annixion-vpn-watch = {
      description = "AnNIXion VPN health check";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${vpnWatch}/bin/annixion-vpn-watch";
      };
    };

    systemd.user.timers.annixion-vpn-watch = {
      description = "Re-check the tunnel is fit for work";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnStartupSec = "1min";
        OnUnitActiveSec = cfg.interval;
        AccuracySec = "30s";
      };
    };

    environment.systemPackages = [
      vpnCheck
      vpnWatch
    ];
  };
}
