# The operator account and the groups a desktop session needs.
#
# No default hashedPassword: every install used to share the same hash.
# `annixion-install`'s wizard collects and hashes a real one into
# user/configuration.nix; an existing-NixOS install sets it there by hand
# (`mkpasswd -m sha-512` — see docs/installation.md Option B).
# system/hardware-stub.nix supplies a locked placeholder so CI and the VM
# tests, which carry no real machine, still evaluate.
{
  config,
  lib,
  ...
}:

{
  users.users.operator = {
    isNormalUser = lib.mkDefault true;
    extraGroups = lib.mkDefault [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
  };

  assertions = [
    {
      assertion = config.users.users.operator.hashedPassword != null;
      message = ''
        users.users.operator.hashedPassword is unset. Run annixion-install's
        wizard, or set it by hand in user/configuration.nix — see
        docs/installation.md.
      '';
    }
  ];
}
