# home/redteam-launch.nix — annixion-redteam, the assault browser and its proxy.
{ pkgs, ... }:

let
  redteam = pkgs.writeShellApplication {
    name = "annixion-redteam";
    runtimeInputs = [
      pkgs.procps
      pkgs.util-linux
    ];
    text = ''
      usage() {
        cat >&2 <<'USAGE'
      usage: annixion-redteam [url...]

      Opens the Red Team browser profile, starting Burp Suite first if no copy
      is already running, so the browser comes up with its proxy behind it.

        -h, --help  show this help
      USAGE
      }

      case "''${1:-}" in
        -h | --help)
          usage
          exit 0
          ;;
      esac

      # Matched on the command line rather than the window: Burp shows nothing
      # for several seconds while the JVM starts, and a window test would start
      # a second copy for every click made in that gap.
      #
      # burpsuite is system-wide (modules/security-tools.nix) and reached
      # through PATH — a JVM and its jar have no business in the home closure.
      if ! pgrep -f burpsuite > /dev/null 2>&1; then
        setsid burpsuite > /dev/null 2>&1 &
      fi

      exec env MOZ_APP_REMOTINGNAME=firefox-red firefox -P "Red Team" --no-remote "$@"
    '';
  };
in
{
  home.packages = [ redteam ];
}
