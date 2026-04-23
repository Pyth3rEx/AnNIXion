{
<<<<<<< HEAD
    description = "Main AnNIXion flake";
=======
    description = "Test flake";
>>>>>>> 7b645ace8466e5e350b8cdbf617ffaa41b75d3bb

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    };

    outputs = { self, nixpkgs, ... }:
    let
        lib = nixpkgs.lib;
    in {
        nixosConfigurations = {
            AnNIXion = lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                    ./configuration.nix
                ];
            };
        };
    };
<<<<<<< HEAD
}
=======
}
>>>>>>> 7b645ace8466e5e350b8cdbf617ffaa41b75d3bb
