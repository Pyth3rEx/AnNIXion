# Whether sudo asks for a password.
{
  lib,
  ...
}:

{
  security.sudo.wheelNeedsPassword = lib.mkDefault true;
}
