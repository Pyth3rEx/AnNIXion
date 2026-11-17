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

  # GC drops whole generations; this hardlinks identical files inside the
  # ones that remain. A toolchain-heavy closure carries a lot of them, and
  # nothing is lost semantically — unlike a shorter GC window, which buys
  # space by throwing away rollback targets (#168).
  nix.optimise = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault [ "weekly" ];
  };
}
