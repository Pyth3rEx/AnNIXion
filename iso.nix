{ lib, pkgs, ... }:
let
  version = lib.removeSuffix "\n" (builtins.readFile ./VERSION);

  installScript = pkgs.writeShellScriptBin "annixion-install"
    (builtins.readFile ./scripts/annixion-install);
in
{
  # ── ISO image metadata ──────────────────────────────────────────────────
  isoImage.isoBaseName = lib.mkForce "AnNIXion";
  isoImage.isoName     = lib.mkForce "AnNIXion-${version}.iso";
  isoImage.volumeID    = lib.mkForce "ANNIXION";
  isoImage.squashfsCompression = "xz -Xdict-size 100%";

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = lib.mkDefault "AnNIXion";
  networking.networkmanager.enable = lib.mkDefault true;

  time.timeZone      = lib.mkDefault "Europe/Paris";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # ── Live user — auto-login to shell ────────────────────────────────────
  users.users.operator = {
    isNormalUser = true;
    password     = "operator";
    extraGroups  = [ "wheel" "networkmanager" "video" "input" ];
  };

  services.getty.autologinUser = lib.mkForce "operator";

  security.sudo.wheelNeedsPassword = lib.mkForce false;

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
    dosfstools   # mkfs.fat
    e2fsprogs    # mkfs.ext4
    networkmanager
    networkmanagerapplet
    pciutils
    usbutils
    wget
    curl
    vim
    nmtui
  ];

  system.stateVersion = "25.11";
}
