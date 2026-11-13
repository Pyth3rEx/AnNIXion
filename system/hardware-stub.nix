# Stand-in disk layout so CI and fresh clones can evaluate and build.
{
  modulesPath,
  lib,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "virtio_pci"
      "sr_mod"
      "virtio_blk"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };
  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # system/core/users.nix and system/sysreptor.nix require a real password
  # hash on every install — annixion-install's wizard sets both, an
  # existing-NixOS install sets them by hand. Neither reaches this stub,
  # which "cannot reach a real machine" (see above), so a placeholder here
  # keeps AnNIXion-ci evaluating without reintroducing a shared real one.
  # mkDefault: a real user/configuration.nix overriding either still wins.
  users.users.operator.hashedPassword = lib.mkDefault "!";
  annixion.sysreptor.hashedPassword = lib.mkDefault "pbkdf2_sha256$600000$ci-stub$ci-stub-is-not-a-real-hash";
}
