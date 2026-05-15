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
  programs.firefox.profiles."puppet" = {
    id = 3;
    name = "Puppet Master";
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

        yandex = {
          name = "Yandex";
          urls = [{ template = "https://yandex.com/search/?text={searchTerms}"; }];
          iconMapObj."16" = "https://yandex.com/favicon.ico";
          definedAliases = [ "@ya" ];
        };

        yandex-images = {
          name = "Yandex Images";
          urls = [{ template = "https://yandex.com/images/search?text={searchTerms}"; }];
          iconMapObj."16" = "https://yandex.com/favicon.ico";
          definedAliases = [ "@yai" ];
        };

        baidu = {
          name = "Baidu";
          urls = [{ template = "https://www.baidu.com/s?wd={searchTerms}"; }];
          iconMapObj."16" = "https://www.baidu.com/favicon.ico";
          definedAliases = [ "@bd" ];
        };

        baidu-images = {
          name = "Baidu Images";
          urls = [{ template = "https://image.baidu.com/search/index?tn=baiduimage&word={searchTerms}"; }];
          iconMapObj."16" = "https://www.baidu.com/favicon.ico";
          definedAliases = [ "@bdi" ];
        };

        social-searcher = {
          name = "Social Searcher";
          urls = [{ template = "https://www.social-searcher.com/social-buzz/?q={searchTerms}"; }];
          definedAliases = [ "@ss" ];
        };

        bing.metaData.hidden = true;
        google.metaData.alias = "@g";
      };
      order = [
        "ddg"
        "yandex"
        "baidu"
        "social-searcher"
        "google"
      ];
    };
    settings = {
      "extensions.autoDisableScopes" = 0;
      # No privatebrowsing.autostart — containers require a regular session
    };
    bookmarks = {
      settings = builtins.fromJSON (builtins.readFile "${config.home.homeDirectory}/.dotfiles/assets/tools/bookmarks-puppet.json");
      force = true;
    };
    extensions = {
      packages = with addons; [
        ublock-origin
        bitwarden
        privacy-badger
        darkreader
        canvasblocker
        user-agent-string-switcher
        cookie-autodelete
        multi-account-containers
        temporary-containers-plus
        single-file
        noscript
        # full list: gitlab.com/rycee/nur-expressions/-/tree/master/pkgs/firefox-addons
      ];
    };
  };

  programs.firefox.policies.ExtensionSettings = with addons; {
    "${ublock-origin.addonId}"              = { private_browsing = true; };
    "${bitwarden.addonId}"                  = { private_browsing = true; };
    "${privacy-badger.addonId}"             = { private_browsing = true; };
    "${darkreader.addonId}"                 = { private_browsing = true; };
    "${canvasblocker.addonId}"              = { private_browsing = true; };
    "${user-agent-string-switcher.addonId}" = { private_browsing = true; };
    "${cookie-autodelete.addonId}"          = { private_browsing = true; };
    "${single-file.addonId}"                = { private_browsing = true; };
    "${noscript.addonId}"                   = { private_browsing = true; };
  };
}