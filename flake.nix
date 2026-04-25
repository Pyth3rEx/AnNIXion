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
      # This makes Home Manager use the same nixpkgs as the system,
      # avoiding duplicate packages being downloaded.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
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
            home-manager.users.operator = import ./home.nix;
          }
        ];
      };
    };
  };
}
