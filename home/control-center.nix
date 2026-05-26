{ config, lib, pkgs, ... }:

# ============================================================
# CONTROL CENTER + META KEY HANDLER
# ============================================================
# Architecture:
#   Single Meta  → opens the AnNIXion Control Center (kdialog menu)
#   Double Meta  → opens Kickoff (start menu)
#
# How it works:
#   kwinrc[ModifierOnlyShortcuts].Meta calls our D-Bus service
#   (org.annixion.MetaKey). The Python service tracks timing:
#   two presses within 400 ms → kickoff, otherwise → control center.
#
# The control center is a kdialog menu that toggles WiFi, BT,
# and will eventually host the network killswitch and VPN controls.
# ============================================================

let
  py = pkgs.python3.withPackages (p: with p; [ dbus-python pygobject3 ]);

  # ── Control center UI ─────────────────────────────────────────────────
  controlCenter = pkgs.writeShellApplication {
    name = "annixion-cc";
    runtimeInputs = with pkgs; [
      networkmanager      # nmcli
      bluez               # bluetoothctl
      kdePackages.kdialog # dialog UI
      procps              # pkill
    ];
    text = ''
      # Toggle: if already open, close it
      if pgrep -x kdialog > /dev/null 2>&1; then
        pkill -x kdialog
        exit 0
      fi

      WIFI=$(nmcli radio wifi 2>/dev/null || echo "unknown")
      BT_RAW=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}')
      BT=$([ "$BT_RAW" = "yes" ] && echo "on" || echo "off")

      CHOICE=$(kdialog \
        --title "Control Center" \
        --menu "AnNIXion Control Center" \
        "wifi"       "Wi-Fi         [$WIFI]" \
        "bt"         "Bluetooth     [$BT]" \
        "killswitch" "Network Killswitch" \
        2>/dev/null) || exit 0

      case "$CHOICE" in
        wifi)
          [ "$WIFI" = "enabled" ] && nmcli radio wifi off || nmcli radio wifi on
          ;;
        bt)
          [ "$BT" = "on" ] && bluetoothctl power off || bluetoothctl power on
          ;;
        killswitch)
          kdialog \
            --warningyesno "Kill ALL network interfaces?\nManual reconnect required to restore." \
            --title "Network Killswitch" 2>/dev/null \
            && nmcli networking off
          ;;
      esac
    '';
  };

  # ── Meta key D-Bus handler ────────────────────────────────────────────
  # Receives every Meta key press from kwin via D-Bus and decides
  # single vs double press based on a 400 ms window.
  metaKeyHandler = pkgs.writeScript "annixion-meta-key-handler" ''
    #!${py}/bin/python3
    import dbus
    import dbus.service
    import dbus.mainloop.glib
    from gi.repository import GLib
    import subprocess
    import time

    DOUBLE_PRESS_MS = 400

    class MetaKeyHandler(dbus.service.Object):
        def __init__(self, bus_name, path):
            super().__init__(bus_name, path)
            self._last  = 0.0
            self._timer = None

        @dbus.service.method("org.annixion.MetaKey",
                             in_signature="", out_signature="")
        def Press(self):
            now        = time.monotonic()
            elapsed_ms = (now - self._last) * 1000

            if self._timer is not None and elapsed_ms < DOUBLE_PRESS_MS:
                # Double press → open kickoff
                GLib.source_remove(self._timer)
                self._timer = None
                self._last  = 0.0
                try:
                    bus   = dbus.SessionBus()
                    shell = bus.get_object("org.kde.plasmashell", "/PlasmaShell")
                    dbus.Interface(shell, "org.kde.PlasmaShell").activateLauncherMenu()
                except Exception:
                    pass
            else:
                # First press — start timer; fire control center if no second press
                self._last = now
                if self._timer is not None:
                    GLib.source_remove(self._timer)
                self._timer = GLib.timeout_add(DOUBLE_PRESS_MS, self._single_press)

        def _single_press(self):
            self._timer = None
            self._last  = 0.0
            subprocess.Popen(["${controlCenter}/bin/annixion-cc"])
            return False   # don't repeat the GLib timeout

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    session_bus = dbus.SessionBus()
    bus_name    = dbus.service.BusName("org.annixion.MetaKey", session_bus)
    MetaKeyHandler(bus_name, "/MetaKey")
    GLib.MainLoop().run()
  '';

in {
  home.packages = [ controlCenter ];

  # Start the handler automatically with the graphical session
  systemd.user.services.annixion-meta-key = {
    Unit = {
      Description = "AnNIXion Meta Key Handler";
      After       = [ "graphical-session.target" ];
      PartOf      = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart  = "${metaKeyHandler}";
      Restart    = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
