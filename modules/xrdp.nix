{ config, lib, pkgs, ... }:

{
  # ============================================================
  # HYPER-V GUEST SUPPORT
  # ============================================================

  # Tell NixOS it's running inside Hyper-V.
  # Loads the right kernel drivers automatically.
  virtualisation.hypervGuest.enable = lib.mkDefault true;

  # Kill the old broken Hyper-V display driver.
  # Forces the system to use hyperv_drm (the modern one) instead.
  boot.blacklistedKernelModules = lib.mkDefault [ "hyperv_fb" ];

  # Load the Hyper-V vsock kernel module at boot.
  # This is the virtual cable Enhanced Session uses.
  boot.kernelModules = lib.mkDefault [ "hv_sock" ];

  # ============================================================
  # XRDP — ENHANCED SESSION
  # ============================================================
  # Hyper-V Enhanced Session connects over vsock (a virtual internal
  # cable) rather than the network. xrdp listens on that cable.

  services.xrdp = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;

    # Launch a proper KDE Plasma X11 session when someone connects.
    # "startplasma-x11" is the standard KDE session launcher — xrdp knows
    # how to set up the environment for it correctly.
    defaultWindowManager = lib.mkDefault "${pkgs.writeShellScript "start-plasma-rdp" ''
      # ── Runtime directory ────────────────────────────────────────────
      # systemd creates this at boot when linger is enabled (see below).
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

      # ── D-Bus ────────────────────────────────────────────────────────
      # With linger enabled, systemd --user manages the bus socket at
      # $XDG_RUNTIME_DIR/bus. Fall back to dbus-launch only if it is
      # somehow absent (e.g. first boot before linger takes effect).
      if ! [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        eval $(${pkgs.dbus}/bin/dbus-launch --sh-syntax --exit-with-session)
      fi

      # ── Inject display environment into systemd user session ─────────
      # In Plasma 6, plasmashell and most shell components are started as
      # systemd user units (via plasma-x11-session.target), not directly
      # by startplasma-x11. Those units inherit systemd --user's environment,
      # not the script's environment, so they can't find the display unless
      # we push the X11 variables in explicitly before Plasma starts.
      # Without this, plasmashell silently fails to launch and you get a
      # black screen with only the cursor (kwin starts fine; it is the
      # shell that depends on these units).
      systemctl --user import-environment \
        DISPLAY XAUTHORITY \
        XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS \
        XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DESKTOP_SESSION \
        QT_QPA_PLATFORM \
        2>/dev/null || true

      # ── Force X11 for Qt and KDE ─────────────────────────────────────
      # In NixOS 26.05, Plasma 6 is Wayland-first. Qt 6 auto-detects the
      # platform and prefers "wayland" when Wayland libraries are present.
      # Inside an xrdp session there is no Wayland compositor, so anything
      # that probes for one hangs waiting for a socket that never comes.
      #
      # unset WAYLAND_DISPLAY  — clears any value inherited from the system
      #   environment so nothing tries to connect to a stale compositor.
      # QT_QPA_PLATFORM=xcb   — forces the X11 backend unconditionally.
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

  # Enable linger for the operator user so systemd --user starts at boot
  # and stays running regardless of how the session is opened.
  # xrdp sessions bypass the normal PAM/logind flow that would otherwise
  # start systemd --user, so without linger, systemctl --user is unavailable
  # and Plasma 6's shell components (started as user units) never launch.
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