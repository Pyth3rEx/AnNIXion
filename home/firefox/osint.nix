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
    };
    bookmarks = {
      settings = builtins.fromJSON (builtins.readFile "${config.home.homeDirectory}/.dotfiles/assets/tools/bookmarks-osint.json");
      force = true;
    };
    extensions = {
      settings = {
        feedbroreader = {
          force = true;
        };
      };
      packages = with addons; [
        ublock-origin
        bitwarden
        privacy-badger
        darkreader
        noscript
        single-file
        multi-account-containers
        temporary-containers-plus
        cookie-autodelete
        canvasblocker
        user-agent-string-switcher
        feedbroreader
        # full list: gitlab.com/rycee/nur-expressions/-/tree/master/pkgs/firefox-addons
      ];
    };
  };
}