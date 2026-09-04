# What the system calls itself. Reads VERSION directly rather than being handed
# it, so the file that owns the number is the only place it is written down.
{
  lib,
  ...
}:

let
  version = lib.removeSuffix "\n" (builtins.readFile ../../VERSION);
in
{
  environment.etc."os-release".text = lib.mkForce ''
    NAME=AnNIXion
    ID=annixion
    VERSION="${version}"
    VERSION_ID="${version}"
    PRETTY_NAME="AnNIXion v${version}"
    HOME_URL="https://github.com/Pyth3rEx/AnNIXion/"
    SUPPORT_URL="https://github.com/Pyth3rEx/AnNIXion/tree/main/docs"
    BUG_REPORT_URL="https://github.com/Pyth3rEx/AnNIXion/issues"
  '';
}
