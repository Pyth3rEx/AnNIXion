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
  virtualisation.hypervGuest.enable = true;

  # "hyperv_fb" is the old broken display driver for Hyper-V.
  # Blacklisting it forces the system to use "hyperv_drm" instead,
  # which gives you a proper working display.
  boot.blacklistedKernelModules = [ "hyperv_fb" ];

  boot.kernelModules = [ "hv_sock" ];

  # ============================================================
  # XRDP — THE REMOTE DESKTOP SERVER
  # ============================================================
  # Hyper-V Enhanced Session connects your Windows host to the VM
  # over an internal virtual cable called "vsock".
  # xrdp is the RDP server that needs to listen on that cable.

  services.xrdp = {
    enable = true;
    openFirewall = true;

    # When someone connects via RDP, launch this script.
    # It sets up the Wayland environment then starts Hyprland.
    defaultWindowManager = "${pkgs.writeShellScript "start-hyprland-rdp" ''
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      export WAYLAND_DISPLAY=wayland-1
      export QT_QPA_PLATFORM=wayland
      export GDK_BACKEND=wayland
      export MOZ_ENABLE_WAYLAND=1
      exec ${pkgs.hyprland}/bin/Hyprland
    ''}";
  };

  # ============================================================
  # VSOCK CONFIG — THE KEY TO ENHANCED SESSION
  # ============================================================
  # The NixOS xrdp module writes xrdp.ini at runtime to a path we
  # can't easily patch at build time. So we hook into the xrdp
  # systemd service with a preStart script that patches the live
  # config file just before xrdp launches.
  #
  # What the two sed commands do:
  #
  #   port=3389  ->  port=vsock://2:3389
  #     Switches xrdp from listening on TCP port 3389 to listening
  #     on the Hyper-V vsock cable. "2" is the Hyper-V host's
  #     Context ID — it is ALWAYS 2, not something you configure.
  #
  #   #vmconnect=true  ->  vmconnect=true
  #     Uncomments this option which enables the vmconnect protocol.
  #     Hyper-V Enhanced Session needs this to negotiate the session.
  systemd.services.xrdp = {
    preStart = lib.mkAfter ''
      cfg=/etc/xrdp/xrdp.ini
      if [ -f "$cfg" ]; then
        sed -i 's|^port=3389|port=vsock://2:3389|' "$cfg"
        sed -i 's|^#vmconnect=true|vmconnect=true|' "$cfg"
      fi
    '';
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
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
  # DISPLAY & DESKTOP
  # ============================================================

  # X11 — needed for XWayland (lets old X11 apps run inside Wayland)
  services.xserver.enable = true;

  # Hyprland — your Wayland window manager
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # GDM — the login screen
  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  services.displayManager.defaultSession = "hyprland";

  # ============================================================
  # AUDIO (Pipewire)
  # ============================================================
  # Enhanced Session passes audio from the VM to Windows.
  # Pipewire is the modern audio system that makes this work.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ============================================================
  # USER ACCOUNT
  # ============================================================
  users.users.operator = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = "$6$DkRVwYEQPe/aYDUp$ULU/oBw9ujsQa5.s4EgWKL2YNNZ2SmEfA0PrMqF6XrZ.FCOsplXdTTEPsWmFH1dU0tB0/JRHeSxasjPBBuQAu1";
    packages = with pkgs; [ tree ];
  };

  # ============================================================
  # PACKAGES
  # ============================================================
  nixpkgs.config.allowUnfree = true;

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    waybar
    kitty
    wofi
    dunst
    grim
    slurp
    wl-clipboard
    git
    gh
    wget
    vscode
  ];

  # ============================================================
  # SSH — uncomment for a fallback way into the VM
  # ============================================================
  # services.openssh.enable = true;

  # ============================================================
  # STATE VERSION — do not change this
  # ============================================================
  system.stateVersion = "26.05";
}
