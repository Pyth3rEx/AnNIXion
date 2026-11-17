#!/usr/bin/env bash
# The greeter has to run the display server the session runs. Nothing errors
# when it does not: SDDM starts a Wayland greeter, hands off to an X11 session,
# and systemd never reaps the greeter scope — a second compositor and ~680 MB
# stay charged to it for the whole uptime (#165). The desktop looks fine, so
# the only place this is visible is `loginctl list-sessions`.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYS='.#nixosConfigurations.AnNIXion-ci.config'
fails=0

report() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" -eq 0 ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s: %s\n' "$name" "$detail"
    fails=$((fails + 1))
  fi
}

cd "$ROOT" || exit 1

# ── The two halves of the handoff ──────────────────────────────────────────
session=$(nix eval --raw "$SYS.services.displayManager.defaultSession" 2>/dev/null)
wayland=$(nix eval "$SYS.services.displayManager.sddm.wayland.enable" 2>/dev/null)

# The invariant, stated once: an X11 session needs an X11 greeter, a Wayland
# session a Wayland one. Either pair is fine; a mismatch is the bug.
case "$session:$wayland" in
  plasmax11:false | plasma:true) ok=0 ;;
  *) ok=1 ;;
esac
report "$ok" "the greeter runs the session's display server" \
  "defaultSession=${session:-<unset>} with sddm.wayland.enable=${wayland:-<unset>}"

# plasma6.nix claims sddm.wayland at mkDefault, which is how the greeter came
# to be Wayland while the session was X11. A definition that loses the merge
# is invisible — the option just reads the other value.
report "$([ "$wayland" = "false" ] && echo 0 || echo 1)" \
  "the X11 greeter wins the merge against plasma6" \
  "sddm.wayland.enable is ${wayland:-<unset>}"

# ── What SDDM is actually told ─────────────────────────────────────────────
# The option is upstream's input; this file is what the greeter reads.
conf=$(nix build --no-link --print-out-paths \
  "$SYS.environment.etc.\"sddm.conf.d/00-nixos.conf\".source" 2>/dev/null)
if [ -z "$conf" ]; then
  report 1 "the greeter config builds" "sddm.conf.d/00-nixos.conf did not build"
else
  server=$(sed -n 's/^DisplayServer=//p' "$conf")
  report "$([ "$server" = "x11" ] && echo 0 || echo 1)" \
    "the greeter config selects X11" "DisplayServer=${server:-<unset>}"

  # Set, this is the kwin_wayland the stranded scope was holding.
  compositor=$(sed -n 's/^CompositorCommand=//p' "$conf")
  report "$([ -z "$compositor" ] && echo 0 || echo 1)" \
    "no greeter compositor is started" "CompositorCommand=$compositor"

  # X11.SessionCommand is how an X11 greeter starts a session at all. Without
  # the X11 section SDDM has nothing to exec and the login goes nowhere.
  report "$(grep -q '^SessionCommand=' "$conf" && echo 0 || echo 1)" \
    "the greeter can start an X11 session" "no SessionCommand in $conf"

  # Dropping the Wayland greeter must not drop the Wayland session from the
  # list — SDDM reads both session dirs, and losing this is how "both sessions
  # are offered" (system/desktop.nix) would quietly stop being true.
  waylandsessions=$(sed -n 's/^SessionDir=.*wayland-sessions.*/yes/p' "$conf" | head -1)
  report "$([ "$waylandsessions" = "yes" ] && echo 0 || echo 1)" \
    "the Wayland session stays selectable" "no wayland-sessions dir in $conf"
fi

echo
if [ "$fails" -gt 0 ]; then
  printf 'greeter-session: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'greeter-session: all checks passed\n'
