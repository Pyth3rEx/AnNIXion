# configuration.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ============================================================
  # HYPER-V GUEST SUPPORT
  # ============================================================

  # Tell NixOS "you are running inside Hyper-V".
  # This loads the right kernel drivers (hv_vmbus, hv_storvsc, etc.)
  # so the VM can talk properly to the Windows host.
  virtualisation.hypervGuest.enable = true;

  # "hyperv_fb" is an old, broken framebuffer driver for Hyper-V.
  # It conflicts with the modern "hyperv_drm" driver.
  # Blacklisting it forces NixOS to use hyperv_drm instead,
  # which gives you a proper display that actually works.
  boot.blacklistedKernelModules = [ "hyperv_fb" ];

  # ============================================================
  # XRDP — THE REMOTE DESKTOP SERVER
  # ============================================================
  # Hyper-V Enhanced Session works by connecting your Windows host
  # to the VM over a special internal cable called "vsock".
  # xrdp is the RDP server that listens on that cable.

  services.xrdp = {
    enable = true;

    # Open port 3389 in the firewall so RDP connections are allowed.
    openFirewall = true;

    # This tells xrdp which desktop to launch when someone connects.
    # For Hyprland + Enhanced Session, we use a small wrapper script
    # that sets up the Wayland environment properly before starting Hyprland.
    defaultWindowManager = "${pkgs.writeShellScript "start-hyprland-rdp" ''
      # Set the Wayland display socket name
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      export WAYLAND_DISPLAY=wayland-1

      # Tell apps to use Wayland, not X11
      export QT_QPA_PLATFORM=wayland
      export GDK_BACKEND=wayland
      export MOZ_ENABLE_WAYLAND=1

      # Launch Hyprland
      exec ${pkgs.hyprland}/bin/Hyprland
    ''}";

    # Override the xrdp package to enable vsock support.
    # "vsock" is the virtual cable that Hyper-V Enhanced Session uses
    # instead of a normal network connection.
    #
    # "overrideAttrs" means: take the default xrdp package and
    # modify it slightly before building.
    package = pkgs.xrdp.overrideAttrs (old: {
      # Add the vsock flag when compiling xrdp from source
      configureFlags = (old.configureFlags or []) ++ [ "--enable-vsock" ];

      # After building, patch the config files to:
      # - use vsock instead of TCP
      # - use RDP security (required for Enhanced Session)
      # - lower encryption overhead (vsock is already internal, no need for heavy crypto)
      postInstall = (old.postInstall or "") + ''
        substituteInPlace $out/etc/xrdp/xrdp.ini \
          --replace "use_vsock=false" "use_vsock=true" \
          --replace "security_layer=negotiate" "security_layer=rdp" \
          --replace "crypt_level=high" "crypt_level=none" \
          --replace "bitmap_compression=true" "bitmap_compression=false"
      '';
    });
  };

  # The vsock connection is handled automatically by xrdp when compiled
  # with --enable-vsock. No extra bridge service is needed.

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
  # Enable modern nix commands (nix run, nix build, etc.) and flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto-clean old system generations weekly.
  # NixOS keeps every old version of your system by default (great for rollbacks),
  # but this would fill your disk. This deletes anything older than 15 days.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 15d";
  };

  # ============================================================
  # LOCALE & TIME
  # ============================================================
  time.timeZone = "Europe/Paris"; # You're in France

  i18n.defaultLocale = "en_US.UTF-8";

  # ============================================================
  # DISPLAY & DESKTOP
  # ============================================================

  # X11 server — needed even for Wayland/Hyprland because some apps
  # still use XWayland (a compatibility layer).
  services.xserver.enable = true;

  # Hyprland — your Wayland compositor (the thing that manages windows).
  programs.hyprland = {
    enable = true;
    # XWayland lets old X11 apps run inside your Wayland session.
    xwayland.enable = true;
  };

  # GDM is the login screen (display manager).
  # It shows before you log in and launches your session.
  services.displayManager.gdm = {
    enable = true;
    wayland = true; # Important: use the Wayland version of GDM
  };

  services.displayManager.defaultSession = "hyprland";

  # ============================================================
  # AUDIO (Pipewire)
  # ============================================================
  # Pipewire is the modern audio system. It replaces PulseAudio.
  # Enhanced Session passes audio from the VM to Windows — pipewire
  # is needed for that to work.
  services.pipewire = {
    enable = true;
    alsa.enable = true;       # support for ALSA apps
    alsa.support32Bit = true; # support for 32-bit ALSA apps
    pulse.enable = true;      # pretend to be PulseAudio (for compatibility)
  };

  # ============================================================
  # USER ACCOUNT
  # ============================================================
  users.users.operator = {
    isNormalUser = true;
    extraGroups = [
      "wheel"        # allows sudo
      "networkmanager" # allows managing network connections
    ];
    hashedPassword = "$6$DkRVwYEQPe/aYDUp$ULU/oBw9ujsQa5.s4EgWKL2YNNZ2SmEfA0PrMqF6XrZ.FCOsplXdTTEPsWmFH1dU0tB0/JRHeSxasjPBBuQAu1";
    packages = with pkgs; [
      tree
    ];
  };

  # ============================================================
  # PACKAGES
  # ============================================================
  nixpkgs.config.allowUnfree = true;

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    # Hyprland ecosystem
    waybar        # status bar at the top/bottom
    kitty         # terminal emulator
    wofi          # app launcher (like a start menu)
    dunst         # notification daemon (shows popups)
    grim          # screenshot tool
    slurp         # screen region selector (used with grim)
    wl-clipboard  # clipboard manager for Wayland

    # Core tools
    git
    gh            # GitHub CLI
    wget

    # Apps
    vscode
  ];

  # ============================================================
  # SSH (optional but recommended for Hyper-V)
  # ============================================================
  # Uncomment this if you want to SSH into the VM as a fallback
  # when Enhanced Session isn't working yet.
  # services.openssh.enable = true;

  # ============================================================
  # STATE VERSION
  # ============================================================
  # DO NOT CHANGE THIS. It's the NixOS version you first installed with.
  # It has nothing to do with which version you're running now.
  system.stateVersion = "26.05";
}
