# Hostname and NetworkManager, with the OpenVPN plugin the killswitch expects.
{
  lib,
  pkgs,
  ...
}:

{
  networking = {
    hostName = lib.mkDefault "AnNIXion";
    networkmanager.enable = lib.mkDefault true;
    networkmanager.plugins = with pkgs; [
      networkmanager-openvpn
    ];
  };
}
