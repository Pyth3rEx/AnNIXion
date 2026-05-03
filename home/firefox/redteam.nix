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
  programs.firefox.profiles."redteam" = {
    id = 1;
    name = "Red Team";
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

        exploit-db = {
          name = "Exploit-DB";
          urls = [{ template = "https://www.exploit-db.com/search?q={searchTerms}"; }];
          iconMapObj."16" = "https://www.exploit-db.com/favicon.ico";
          definedAliases = [ "@edb" ];
        };

        cve = {
          name = "CVE Search";
          urls = [{ template = "https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword={searchTerms}"; }];
          definedAliases = [ "@cve" ];
        };

        nvd = {
          name = "NVD";
          urls = [{ template = "https://nvd.nist.gov/vuln/search/results?query={searchTerms}"; }];
          definedAliases = [ "@nvd" ];
        };

        bing.metaData.hidden = true;
        google.metaData.alias = "@g";
      };
      order = [
        "ddg"
        "exploit-db"
        "cve"
        "nvd"
        "google"
      ];
    };
    settings = {
      "extensions.autoDisableScopes" = 0;
      "browser.privatebrowsing.autostart" = true;
    };
    bookmarks = {
      settings = builtins.fromJSON (builtins.readFile "${config.home.homeDirectory}/.dotfiles/assets/tools/bookmarks-redteam.json");
      force = true;
    };
    extensions = {
      packages = with addons; [
        ublock-origin
        bitwarden
        privacy-badger
        darkreader
        foxyproxy-standard
        single-file
        hacktools
        cookie-editor
        # full list: gitlab.com/rycee/nur-expressions/-/tree/master/pkgs/firefox-addons
      ];
    };
  };
}