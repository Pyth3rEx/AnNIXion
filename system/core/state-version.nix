# Never change this. It records the release the system was installed at, and
# is what NixOS reads to decide which stateful defaults still apply.
{
  lib,
  ...
}:

{
  system.stateVersion = lib.mkDefault "26.05";
}
