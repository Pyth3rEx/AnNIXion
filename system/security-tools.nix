# System-wide offensive, OSINT, RF and forensics tooling.
#
# The list is catalog/, not this file: every tool declares its package beside
# its menu entry and its mark, so a tool cannot be installed without appearing
# in the menu, or drawn without being installed. Add one by adding one file.
{
  pkgs,
  lib,
  ...
}:

let
  catalog = import ../catalog { inherit lib; };
in
{
  # System-wide, so they are present before any user session starts.
  # Unfree packages need allowUnfree, set in flake.nix.
  environment.systemPackages = catalog.packages pkgs;
}
