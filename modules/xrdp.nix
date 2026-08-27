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

    # vmconnect widens the security protocols Enhanced Session negotiates.
    # Console logging is the only route xrdp's own log has to the journal:
    # nixpkgs points LogFile at /dev/null and turns syslog off, which is why
    # a failed connection leaves nothing behind to read.
    extraConfDirCommands = ''
      substituteInPlace $out/xrdp.ini \
        --replace-fail "#vmconnect=true" "vmconnect=true" \
        --replace-fail "#EnableConsole=false" "EnableConsole=true"
      substituteInPlace $out/sesman.ini \
        --replace-fail "#EnableConsole=false" "EnableConsole=true"
    '';

    # startplasma-x11 is the session launcher xrdp knows how to set up.
    defaultWindowManager = lib.mkDefault "${pkgs.writeShellScript "annixion-start-plasma-rdp" ''
      # ── Runtime directory ────────────────────────────────────────────
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

      # ── systemd --user ───────────────────────────────────────────────
      # pam_systemd starts the manager when the session opens, but not
      # synchronously, and everything below needs it reachable first.
      for _ in $(seq 100); do
        systemctl --user show-environment >/dev/null 2>&1 && break
        sleep 0.1
      done

      # ── D-Bus ────────────────────────────────────────────────────────
      # systemd --user owns the bus socket; dbus-launch is the fallback
      # for a session that reaches here without one.
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

  # ── Audio — redirected over RDP ───────────────────────────
  # Hyper-V emulates no sound card, so xrdp's channel is the only way out.
  # PulseAudio, not PipeWire: module-xrdp-sink is a native daemon module and
  # pipewire-pulse cannot load it. See docs/installation.md.
  services.pipewire = {
    enable = false;
    pulse.enable = false;
  };

  services.pulseaudio = {
    enable = lib.mkDefault true;
    support32Bit = lib.mkDefault true;
  };

  services.xrdp.audio.enable = lib.mkDefault true;

  # pam_systemd registers the xrdp session with logind, so the user manager
  # starts with the session and must die with it: left lingering it holds
  # graphical-session.target active against a dead DISPLAY, and the next
  # login finds Plasma already started and never gets a shell. Explicitly
  # false, not absent — NixOS only runs disable-linger for users set false,
  # so unsetting it would strand the stamp file on machines that have one.
  users.users.operator.linger = lib.mkDefault false;

  # ── vsock transport ───────────────────────────────────────
  # Listen on vsock://-1:3389 (VMADDR_CID_ANY) rather than TCP — this is
  # what Enhanced Session connects to. mkForce must beat xrdp's own
  # ExecStart; it is required, not a user-tunable default.
  systemd.services.xrdp = {
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.xrdp}/bin/xrdp --nodaemon --port vsock://-1:3389 --config /etc/xrdp/xrdp.ini";
    };
  };
}
