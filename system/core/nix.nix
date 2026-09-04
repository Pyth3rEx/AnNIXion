# Flakes, and the garbage collection that stops old generations piling up.
{
  lib,
  ...
}:

{
  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];

  # Old generations pile up otherwise.
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 15d";
  };
}
