# Pipewire. system/xrdp.nix swaps this for PulseAudio on Hyper-V.
{
  lib,
  ...
}:

{
  # Hyper-V has no sound card: system/xrdp.nix swaps this for
  # PulseAudio, the only stack xrdp can redirect audio through.
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };
}
