# flake.nix
{
  description = "Main AnNIXion flake";

  inputs = {
    # Main nixpkgs — your system packages come from here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Home Manager — declares your user environment (dotfiles,
    # shortcuts, apps) in Nix. Follows the same nixpkgs version.
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # plasma-manager — lets you declare KDE Plasma settings in Nix.
    # Without this, programs.plasma doesn't exist in Home Manager.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, ... }:
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations = {
      AnNIXion = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix

          # Wire Home Manager into the NixOS build.
          # This means "nixos-rebuild switch" handles both system
          # AND user config in one command — no separate step needed.
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;   # share system pkgs
            home-manager.useUserPackages = true;  # install to user profile
            # Give Home Manager access to the plasma-manager module
            home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager ];
            home-manager.users.operator = import ./home.nix;
          }
        ];
      };
    };
  };
}
