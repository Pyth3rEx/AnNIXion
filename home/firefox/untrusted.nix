{ inputs, config, lib, pkgs, ... }:

let
  repoRoot = inputs.firefox-addons.sourceInfo.outPath;
  libMozilla = import "${repoRoot}/lib/mozilla.nix" { lib = pkgs.lib; };
  buildMozillaXpiAddon = libMozilla.mkBuildMozillaXpiAddon { inherit (pkgs) fetchurl stdenv; };
  addons = import "${inputs.firefox-addons}" {
    inherit buildMozillaXpiAddon;
    inherit (pkgs) fetchurl lib stdenv;
  };
in
{
  programs.firefox.profiles."untrusted" = {
    id = 0;
    isDefault = true;
    name = "Unsafe Browser";
    settings = {
      "extensions.autoDisableScopes" = 0;
      "network.proxy.type" = 0;
    };
    extensions = {
      packages = with addons; [
        ublock-origin
      ];
    };
  };
}
