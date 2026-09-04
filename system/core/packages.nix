# The handful of packages that are not tools. Tools come from catalog/.
{
  lib,
  pkgs,
  ...
}:

{
  # Tool packages live in system/security-tools.nix.
  nixpkgs.config.allowUnfree = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    networkmanager
    networkmanagerapplet
    openvpn
    wireguard-tools
    kdePackages.kservice
  ];

  # A real file so root can edit it; world-readable or every non-root
  # name lookup and the rootless container runtime lose /etc/hosts.
  environment.etc.hosts.mode = "0644";
}
