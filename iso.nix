{ lib, pkgs, ... }:
let
  version = lib.removeSuffix "\n" (builtins.readFile ./VERSION);
in
{
  imports = [
    ./modules/security-tools.nix
    ./modules/desktop.nix
  ];

  # ── ISO image metadata ──────────────────────────────────────────
  isoImage.isoBaseName = lib.mkForce "AnNIXion";
  isoImage.isoName     = lib.mkForce "AnNIXion-${version}.iso";
  isoImage.volumeID    = lib.mkForce "ANNIXION";
  # zstd gives a better size/speed tradeoff than the default xz
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = lib.mkDefault "AnNIXion";
  networking.networkmanager.enable = lib.mkDefault true;

  time.timeZone      = lib.mkDefault "Europe/Paris";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  services.pipewire = {
    enable           = lib.mkDefault true;
    alsa.enable      = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable     = lib.mkDefault true;
  };

  # ── Live session user ───────────────────────────────────────────
  # Credentials are operator / operator — shown on the desktop wallpaper
  # via the installation CD module's default messaging.
  users.users.operator = {
    isNormalUser = true;
    password     = "operator";
    extraGroups  = [ "wheel" "networkmanager" "video" "input" ];
    shell        = pkgs.zsh;
  };

  # Auto-login into the live desktop — no password prompt on first boot.
  services.displayManager.autoLogin.enable = lib.mkForce true;
  services.displayManager.autoLogin.user   = lib.mkForce "operator";

  # Passwordless sudo for the live session; the installed system will
  # restore the normal password requirement via configuration.nix.
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    networkmanager
    networkmanagerapplet
    git
    wget
    curl
  ];

  system.stateVersion = "26.05";
}
