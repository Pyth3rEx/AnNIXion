{ config, pkgs, lib, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-base.nix>
    ./modules/installer.nix
  ];

  # ISO metadata
  isoImage.isoBaseName = "annixion";
  isoImage.volumeID = "ANNIXION";
  
  # Installer configuration
  annixion.installer.enable = true;

  # Minimal X11 for troubleshooting (optional, can disable for pure TUI)
  services.xserver.enable = lib.mkForce false;

  # Boot parameters
  boot.kernelParams = [
    "quiet"
    "loglevel=2"
  ];

  # Networking
  networking.useDHCP = true;
  networking.wireless.enable = true;

  # SSH for remote installation (optional)
  services.openssh.enable = false;

  # Timezone for build consistency
  time.timeZone = "UTC";

  # System version
  system.stateVersion = "24.05";
}
