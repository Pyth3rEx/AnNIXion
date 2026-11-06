# Which of the four Firefox profiles to build. Home Manager owns the
# profiles themselves (home/firefox/*.nix); this is read there through
# osConfig, the same way annixion.desktop.compositing is (system/desktop.nix).
{ lib, config, ... }:

let
  names = [
    "redteam"
    "osint"
    "puppet"
    "untrusted"
  ];
in
{
  options.annixion.firefox.profiles = {
    redteam.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Build the Red Team profile, its Burp-paired launcher (annixion-redteam) and its menu entry.";
    };
    osint.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Build the OSINT profile, its launcher and its menu entry.";
    };
    puppet.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Build the Puppet Master profile, its launcher and its menu entry.";
    };
    untrusted.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Build the Unsafe Browser profile, its launcher and its menu entry.";
    };
  };

  config.assertions = [
    {
      assertion = lib.any (n: config.annixion.firefox.profiles.${n}.enable) names;
      message = "All four Firefox profiles are disabled (annixion.firefox.profiles.*.enable) — at least one must stay on.";
    }
  ];
}
