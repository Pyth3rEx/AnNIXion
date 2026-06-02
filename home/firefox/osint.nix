{ inputs, config, lib, pkgs, ... }:

let
  repoRoot = inputs.firefox-addons.sourceInfo.outPath;
  libMozilla = import "${repoRoot}/lib/mozilla.nix" { lib = pkgs.lib; };
  buildMozillaXpiAddon = libMozilla.mkBuildMozillaXpiAddon { inherit (pkgs) fetchurl stdenv; };
  addons = import "${inputs.firefox-addons}" {
    inherit buildMozillaXpiAddon;
    inherit (pkgs) fetchurl lib stdenv;
  };
  burnedLand = import ./burned-land.nix { inherit pkgs; };
in
{
  programs.firefox.profiles."osint" = {
    id = 2;
    name = "OSINT";
    search = {
      default = "ddg";
      privateDefault = "ddg";
      force = true;
      engines = {
        nix-packages = {
          name = "Nix Packages";
          urls = [{
            template = "https://search.nixos.org/packages";
            params = [
              { name = "type"; value = "packages"; }
              { name = "query"; value = "{searchTerms}"; }
            ];
          }];
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [ "@np" ];
        };

        nixos-wiki = {
          name = "NixOS Wiki";
          urls = [{ template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; }];
          iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
          definedAliases = [ "@nw" ];
        };

        shodan = {
          name = "Shodan";
          urls = [{ template = "https://www.shodan.io/search?query={searchTerms}"; }];
          iconMapObj."16" = "https://www.shodan.io/favicon.ico";
          definedAliases = [ "@sh" ];
        };

        censys = {
          name = "Censys";
          urls = [{ template = "https://search.censys.io/search?resource=hosts&q={searchTerms}"; }];
          definedAliases = [ "@cs" ];
        };

        wayback = {
          name = "Wayback Machine";
          urls = [{ template = "https://web.archive.org/web/*/{searchTerms}"; }];
          iconMapObj."16" = "https://archive.org/favicon.ico";
          definedAliases = [ "@wb" ];
        };

        bing.metaData.hidden = true;
        google.metaData.alias = "@g";
      };
      order = [
        "ddg"
        "shodan"
        "censys"
        "wayback"
        "google"
      ];
    };
    settings = {
      "extensions.autoDisableScopes" = 0;
      "browser.privatebrowsing.autostart" = true;
      "network.proxy.type" = 1;
      "network.proxy.socks" = "127.0.0.1";
      "network.proxy.socks_port" = 1080;
      "network.proxy.socks_version" = 5;
      "network.proxy.socks_remote_dns" = true;
      "network.proxy.failover_direct" = false;
    };
    bookmarks = {
      settings = builtins.fromJSON (builtins.readFile "${config.home.homeDirectory}/.dotfiles/assets/tools/bookmarks-osint.json");
      force = true;
    };
    extensions = {
      settings = {
        feedbroreader = {
          force = true; # Example option
        };
      };
      packages = with addons; [
        ublock-origin
        bitwarden
        privacy-badger
        darkreader
        noscript
        single-file
        cookie-autodelete
        canvasblocker
        user-agent-string-switcher
        feedbroreader
        burnedLand
        # full list: gitlab.com/rycee/nur-expressions/-/tree/master/pkgs/firefox-addons
      ];
    };
  };

  programs.firefox.policies.ExtensionSettings = with addons; {
    "${ublock-origin.addonId}"              = { private_browsing = true; };
    "${bitwarden.addonId}"                  = { private_browsing = true; };
    "${privacy-badger.addonId}"             = { private_browsing = true; };
    "${darkreader.addonId}"                 = { private_browsing = true; };
    "${noscript.addonId}"                   = { private_browsing = true; };
    "${single-file.addonId}"                = { private_browsing = true; };
    "${cookie-autodelete.addonId}"          = { private_browsing = true; };
    "${canvasblocker.addonId}"              = { private_browsing = true; };
    "${user-agent-string-switcher.addonId}" = { private_browsing = true; };
    "${feedbroreader.addonId}"              = { private_browsing = true; };
    "${burnedLand.addonId}"                 = { private_browsing = true; };
  };
}