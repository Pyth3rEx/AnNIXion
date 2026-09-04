# home/desktop/window-raise.nix — annixion-raise, the launch-or-focus helper.
{ pkgs, ... }:

let
  raise = pkgs.writeShellApplication {
    name = "annixion-raise";
    runtimeInputs = [
      pkgs.wmctrl
      pkgs.xprop
    ];
    text = ''
      usage() {
        cat >&2 <<'USAGE'
      usage: annixion-raise <wm-class-glob> <command> [args...]

      Focuses a running window instead of starting a second copy. The glob is
      matched, case-insensitively, against a window's WM_CLASS instance, its
      class, and the "instance.class" pair. Repeated calls cycle through the
      matches; with no match at all, the command runs.

        -h, --help  show this help
      USAGE
      }

      case "''${1:-}" in
        -h | --help)
          usage
          exit 0
          ;;
      esac

      if [ $# -lt 2 ]; then
        usage
        exit 64
      fi

      PATTERN="$1"
      shift

      ACTIVE="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | grep -o '0x[0-9a-f]*' | head -n1 || true)"
      ACTIVE="''${ACTIVE:-0x0}"

      MATCHES=()
      while read -r id _ wmclass _; do
        instance="''${wmclass%%.*}"
        class="''${wmclass#*.}"
        shopt -s nocasematch
        # shellcheck disable=SC2053 # unquoted RHS is the glob match, on purpose
        if [[ "$wmclass" == $PATTERN || "$instance" == $PATTERN || "$class" == $PATTERN ]]; then
          MATCHES+=("$id")
        fi
        shopt -u nocasematch
      done < <(wmctrl -l -x || true)

      if [ ''${#MATCHES[@]} -eq 0 ]; then
        exec "$@"
      fi

      NEXT="''${MATCHES[0]}"
      for i in "''${!MATCHES[@]}"; do
        if [ "$((MATCHES[i]))" -eq "$((ACTIVE))" ]; then
          NEXT="''${MATCHES[$(((i + 1) % ''${#MATCHES[@]}))]}"
          break
        fi
      done

      exec wmctrl -i -a "$NEXT"
    '';
  };
in
{
  home.packages = [ raise ];
}
