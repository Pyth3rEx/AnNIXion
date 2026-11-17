# Hostname and NetworkManager, with the OpenVPN plugin the killswitch expects.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.annixion.hardware.wireless = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = ''
      Let NetworkManager manage wireless interfaces.

      Off by default because the deployment target is a Hyper-V guest with
      no radio: `/sys/class/ieee80211` does not exist and `/sys/class/net`
      holds an ethernet device and the VPN tunnel. NetworkManager still
      turns `networking.wireless` on there unconditionally — its wifi
      backend defaults to wpa_supplicant — so the daemon runs for the whole
      uptime with nothing to manage (#168).

      On restores wpa_supplicant and wifi support, which is what any
      install with a radio wants. Check with `ls /sys/class/ieee80211`;
      if that directory exists, turn this on.

      Nothing else depends on it: ethernet, the OpenVPN plugin and the
      killswitch are unaffected either way.
    '';
  };

  config = {
    networking = {
      hostName = lib.mkDefault "AnNIXion";
      networkmanager.enable = lib.mkDefault true;
      networkmanager.plugins = with pkgs; [
        networkmanager-openvpn
      ];

      # NetworkManager sets this at normal priority, so declining it needs
      # mkForce rather than the usual mkDefault.
      wireless.enable = lib.mkIf (!config.annixion.hardware.wireless) (lib.mkForce false);
    };
  };
}
