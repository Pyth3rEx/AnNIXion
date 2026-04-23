{ config, pkgs, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.user = {
    /* The home.stateVersion option does not have a default and must be set */
    home.stateVersion = "26.05";

    /* home-manager config below this point */
    programs.bash = {
      enable = true;
      shellAliases = {
        rebuild-reboot = "sudo nixos-rebuild switch --flake .#AnNIXion && sudo reboot";
        rebuild-test = "sudo nixos-rebuild test --flake .#AnNIXions";
      };
    };
  };
}
