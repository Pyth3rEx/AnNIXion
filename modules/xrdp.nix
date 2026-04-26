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
      # Set up runtime directory for this user session
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

      # Start a D-Bus session if one isn't running
      if ! [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        eval $(${pkgs.dbus}/bin/dbus-launch --sh-syntax --exit-with-session)
      fi

      # Required for Plasma to find its components
      export XDG_SESSION_TYPE=x11
      export DESKTOP_SESSION=plasma
      export XDG_CURRENT_DESKTOP=KDE

      exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11
    ''}";
  };

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