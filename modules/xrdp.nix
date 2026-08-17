{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ── HYPER-V GUEST SUPPORT ─────────────────────────────────

  # Tell NixOS it's running inside Hyper-V.
  # Loads the right kernel drivers automatically.
  virtualisation.hypervGuest.enable = lib.mkDefault true;

  # Kill the old broken Hyper-V display driver.
  # Forces the system to use hyperv_drm (the modern one) instead.
  boot.blacklistedKernelModules = lib.mkDefault [ "hyperv_fb" ];

  # Load the Hyper-V vsock kernel module at boot.
  # This is the virtual cable Enhanced Session uses.
  boot.kernelModules = lib.mkDefault [ "hv_sock" ];

  # ── XRDP — ENHANCED SESSION ───────────────────────────────
  # Enhanced Session connects over vsock, not the network.

  services.xrdp = {
    enable = lib.mkDefault true;
    # vsock only — the TCP port would have nothing behind it. Bare
    # metal RDP needs this back to true.
    openFirewall = lib.mkDefault false;

    # startplasma-x11 is the session launcher xrdp knows how to set up.
    defaultWindowManager = lib.mkDefault "${pkgs.writeShellScript "annixion-start-plasma-rdp" ''
      # ── Runtime directory ────────────────────────────────────────────
      # systemd creates this at boot when linger is enabled (see below).
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

      # ── D-Bus ────────────────────────────────────────────────────────
      # linger means systemd --user owns the bus socket; dbus-launch is
      # the fallback for first boot.
      if ! [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        eval $(${pkgs.dbus}/bin/dbus-launch --sh-syntax --exit-with-session)
      fi

      # ── Inject display environment into systemd user session ─────────
      # Plasma 6 starts plasmashell as a systemd user unit, which inherits
      # systemd --user's environment rather than this script's. Without
      # this push, plasmashell never launches: black screen with a cursor.
      systemctl --user import-environment \
        DISPLAY XAUTHORITY \
        XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS \
        XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DESKTOP_SESSION \
        QT_QPA_PLATFORM \
        2>/dev/null || true

      # ── Force X11 for Qt and KDE ─────────────────────────────────────
      # Qt 6 prefers Wayland when its libraries are present. There is no
      # compositor in an xrdp session, so probing hangs.
      unset WAYLAND_DISPLAY
      export QT_QPA_PLATFORM=xcb

      export XDG_SESSION_TYPE=x11
      export DESKTOP_SESSION=plasma
      export XDG_CURRENT_DESKTOP=KDE

      # KWin rewrites kwinrc on session exit, stomping plasma-manager's config.
      # Re-apply the keys we care about on every session start, before Plasma loads.
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group ModifierOnlyShortcuts --key Meta \
        "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Number 4
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Rows 1

      exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11
    ''}";
  };

  # xrdp bypasses the PAM/logind flow that starts systemd --user, so
  # without linger the Plasma 6 shell units never launch.
  users.users.operator.linger = lib.mkDefault true;

  # Override xrdp's ExecStart to listen on vsock://-1:3389 instead
  # of TCP. -1 means VMADDR_CID_ANY — accept from any CID.
  # This is what makes Enhanced Session actually connect.
  #
  # lib.mkForce is intentional here — it must beat xrdp's own default
  # ExecStart. This is not a user-configurable default; it is a
  # required system-level override for vsock transport to work.
  systemd.services.xrdp = {
    preStart = lib.mkAfter ''
      cfg=/etc/xrdp/xrdp.ini
      if [ -f "$cfg" ]; then
        sed -i 's|^#vmconnect=true|vmconnect=true|' "$cfg"
      fi
    '';
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.xrdp}/bin/xrdp --nodaemon --port vsock://-1:3389 --config /etc/xrdp/xrdp.ini";
    };
  };
}
