# Hyper-V guest support and Enhanced Session over vsock.
{
  lib,
  pkgs,
  ...
}:

{
  # ── Hyper-V guest support ─────────────────────────────────
  virtualisation.hypervGuest.enable = lib.mkDefault true;

  # Blacklisted so the modern hyperv_drm driver is used instead.
  boot.blacklistedKernelModules = lib.mkDefault [ "hyperv_fb" ];

  # The virtual cable Enhanced Session runs over.
  boot.kernelModules = lib.mkDefault [ "hv_sock" ];

  # ── xrdp — Enhanced Session ───────────────────────────────
  # Enhanced Session connects over vsock, not the network.

  services.xrdp = {
    enable = lib.mkDefault true;
    # vsock only — the TCP port would have nothing behind it. Bare
    # metal RDP needs this back to true.
    openFirewall = lib.mkDefault false;

    # startplasma-x11 is the session launcher xrdp knows how to set up.
    defaultWindowManager = lib.mkDefault "${pkgs.writeShellScript "annixion-start-plasma-rdp" ''
      # ── Runtime directory ────────────────────────────────────────────
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

      # ── D-Bus ────────────────────────────────────────────────────────
      # linger means systemd --user owns the bus socket; dbus-launch is
      # the fallback for first boot.
      if ! [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        eval $(${pkgs.dbus}/bin/dbus-launch --sh-syntax --exit-with-session)
      fi

      # ── Inject display environment into systemd user session ─────────
      # plasmashell is a systemd user unit and inherits systemd --user's
      # environment, not this script's. Without it: black screen.
      systemctl --user import-environment \
        DISPLAY XAUTHORITY \
        XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS \
        XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DESKTOP_SESSION \
        QT_QPA_PLATFORM \
        2>/dev/null || true

      # ── Force X11 for Qt and KDE ─────────────────────────────────────
      # Qt 6 probes for Wayland, and an xrdp session has no compositor.
      unset WAYLAND_DISPLAY
      export QT_QPA_PLATFORM=xcb

      export XDG_SESSION_TYPE=x11
      export DESKTOP_SESSION=plasma
      export XDG_CURRENT_DESKTOP=KDE

      # ── Re-apply keys KWin stomps on session exit ────────────────────
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

  # ── vsock transport ───────────────────────────────────────
  # Listen on vsock://-1:3389 (VMADDR_CID_ANY) rather than TCP — this is
  # what Enhanced Session connects to. mkForce must beat xrdp's own
  # ExecStart; it is required, not a user-tunable default.
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
