# Applies the repo's nixpkgs overlays (../overlays.nix) to the system configs.
# The test package instances in flake.nix apply the same list directly, since a
# nixosTest pins nixpkgs.pkgs on its nodes and so ignores nixpkgs.overlays.
{ inputs, ... }:
{
  nixpkgs.overlays = import ../overlays.nix { inherit inputs; };
}
