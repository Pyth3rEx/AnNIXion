# The boot loader. systemd-boot, and the EFI vars it needs to write.
{
  lib,
  ...
}:

{
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
