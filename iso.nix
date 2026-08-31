# Live installer ISO: auto-login shell with annixion-install on PATH.
{ lib, pkgs, ... }:
let
  version = lib.removeSuffix "\n" (builtins.readFile ./VERSION);
  branding = import ./branding { inherit pkgs; };

  # Build the installer script as an ordinary executable
  installScript = pkgs.writeShellScriptBin "annixion-install" (
    builtins.readFile ./scripts/annixion-install
  );
in
{
  # ── ISO image metadata ──────────────────────────────────────────────────
  image = {
    baseName = lib.mkForce "AnNIXion";
    fileName = lib.mkForce "AnNIXion-${version}.iso";
  };
  isoImage = {
    volumeID = lib.mkForce "ANNIXION";
    squashfsCompression = "xz -Xdict-size 100%";

    # syslinux draws the BIOS menu over the first, GRUB the EFI one. Both
    # default to NixOS artwork fetched from GitHub, so overriding them also
    # drops two fetchurls from the ISO's evaluation.
    splashImage = lib.mkForce branding.isoSplashBios;
    efiSplashImage = lib.mkForce branding.isoSplashEfi;
  };

  boot = {
    # The new default from 26.11; the live image never imports a root pool it
    # did not create.
    zfs.forceImportRoot = false;

    # The live image is a console session, so the splash is the only place the
    # mark appears between the boot menu and the installer prompt.
    plymouth = {
      enable = true;
      themePackages = [ branding.plymouthTheme ];
      theme = "annixion";
    };
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
    ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.hostName = lib.mkDefault "AnNIXion";
  networking.networkmanager.enable = lib.mkDefault true;

  time.timeZone = lib.mkDefault "Europe/Paris";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # ── Live user — auto‑login to shell ────────────────────────────────────
  users.users.operator = {
    isNormalUser = true;
    password = "operator";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
  };
  services.getty.autologinUser = lib.mkForce "operator";

  # Allow password‑less sudo for the installer
  security.sudo.wheelNeedsPassword = lib.mkForce false;
  security.sudo.extraConfig = ''
    # The operator may run the installer as root without a password.
    operator ALL=(ALL) NOPASSWD: ${installScript}/bin/annixion-install
  '';

  # ── Greet the user and hint at the installer ───────────────────────────
  users.users.operator.packages = [ pkgs.figlet ];
  environment.interactiveShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      echo ""
      echo "  Welcome to AnNIXion ${version}"
      echo ""
      echo "  Run  annixion-install  to install AnNIXion onto this machine."
      echo "  Network is managed by NetworkManager — use  nmtui  to connect."
      echo ""
    fi
  '';

  # ── Packages available in the live session ─────────────────────────────
  environment.systemPackages = with pkgs; [
    installScript
    git
    parted
    dosfstools # mkfs.fat
    e2fsprogs # mkfs.ext4
    networkmanager
    networkmanagerapplet
    pciutils
    usbutils
    wget
    curl
    vim
  ];

  system.stateVersion = "26.05";
}
