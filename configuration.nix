# configuration.nix
{ config, lib, pkgs, ... }:

{
  imports = [];

  # ============================================================
  # HYPER-V GUEST SUPPORT
  # ============================================================

  # Tell NixOS it's running inside Hyper-V.
  # Loads the right kernel drivers automatically.
  virtualisation.hypervGuest.enable = true;

  # Kill the old broken Hyper-V display driver.
  # Forces the system to use hyperv_drm (the modern one) instead.
  boot.blacklistedKernelModules = [ "hyperv_fb" ];

  # Load the Hyper-V vsock kernel module at boot.
  # This is the virtual cable Enhanced Session uses.
  boot.kernelModules = [ "hv_sock" ];

  # ============================================================
  # XRDP — ENHANCED SESSION
  # ============================================================
  # Hyper-V Enhanced Session connects over vsock (a virtual internal
  # cable) rather than the network. xrdp listens on that cable.

  services.xrdp = {
    enable = true;
    openFirewall = true;

    # Launch a proper KDE Plasma X11 session when someone connects.
    # "startkde" is the standard KDE session launcher — xrdp knows
    # how to set up the environment for it correctly.
    defaultWindowManager = "${pkgs.writeShellScript "start-plasma-rdp" ''
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

  # ============================================================
  # BOOT LOADER
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ============================================================
  # NETWORKING
  # ============================================================
  networking.hostName = "AnNIXion";
  networking.networkmanager.enable = true;

  # ============================================================
  # NIX SETTINGS
  # ============================================================
  # Enable modern nix commands (nix run, nix build, nix flake etc.)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto-delete old system generations older than 15 days.
  # NixOS keeps every old version for rollback — this prevents
  # your disk filling up over time.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 15d";
  };

  # ============================================================
  # LOCALE & TIME
  # ============================================================
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # ============================================================
  # DISPLAY & DESKTOP — KDE PLASMA (X11)
  # ============================================================

  # X11 display server — KDE runs on top of this.
  services.xserver = {
    enable = true;

    # SDDM is KDE's login screen. It's the one that knows how to
    # launch a proper Plasma session for both local and xrdp use.
    displayManager.sddm.enable = true;

    # KDE Plasma 6 — the full desktop environment.
    desktopManager.plasma6.enable = true;
  };

  # ============================================================
  # AUDIO (Pipewire)
  # ============================================================
  # Enhanced Session passes audio from the VM to Windows.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ============================================================
  # SECURITY & PAM
  # ============================================================
  # KDE Wallet stores secrets (WiFi passwords, SSH keys etc.)
  # This makes it unlock automatically on login.
  security.pam.services.sddm.enableKwallet = true;

  # Allow users in the "wheel" group to use sudo.
  security.sudo.wheelNeedsPassword = true;

  # ============================================================
  # USER ACCOUNT
  # ============================================================
  users.users.operator = {
    isNormalUser = true;
    extraGroups = [
      "wheel"          # sudo access
      "networkmanager" # manage network connections
      "video"          # needed for some hardware tools
      "input"          # needed for input devices
    ];
    hashedPassword = "$6$DkRVwYEQPe/aYDUp$ULU/oBw9ujsQa5.s4EgWKL2YNNZ2SmEfA0PrMqF6XrZ.FCOsplXdTTEPsWmFH1dU0tB0/JRHeSxasjPBBuQAu1";
  };

  # ============================================================
  # SYSTEM PACKAGES
  # ============================================================
  # These are installed system-wide, available to all users.
  # User-specific tools go in home.nix instead.
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # Core utilities
    git
    wget
    curl
    htop
    tree

    # KDE extras that aren't pulled in automatically
    kdePackages.kate          # KDE text editor
    kdePackages.ark           # archive manager
    kdePackages.kcalc         # calculator
    kdePackages.filelight     # disk usage visualizer
    kdePackages.kwalletmanager

    # Networking tools
    networkmanager
  ];

  # Some KDE programs need to be enabled this way rather than
  # just added to systemPackages.
  programs.firefox.enable = true;

  # ============================================================
  # SSH — useful fallback if xrdp has issues
  # ============================================================
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # ============================================================
  # STATE VERSION — do not change this ever
  # ============================================================
  # This is the NixOS version you first installed with.
  # It controls stateful defaults. Changing it breaks things.
  system.stateVersion = "26.05";
}
