# Addons need to be turned on (allowed in private windows) manual
# It's not a bug... it's a feature!


# Update: just learned that firefox handles "allow in private windows" as runtime security policy, and therefore janky to mess with as declarative. I'll need to dig more if we want to change that (do we?)

{ inputs, config, lib, pkgs, ...}:

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
  programs.firefox.enable = lib.mkDefault true;

  xdg.desktopEntries = lib.mkDefault {
    firefox = {                   
      name = "Firefox";                              
      noDisplay = true;                              
    };
    firefox-red = {
      name = "Firefox - Red Team";
      icon = "${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-red.png";
      genericName = "Assault Browser";
      exec = ''firefox -P "Red Team" --no-remote'';
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
      mimeType = [ "text/html" "text/xml" ];
    };
    firefox-osint = { 
      name = "Firefox - OSINT";
      icon = "${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-yellow.png";
      genericName = "Search Browser";
      exec = ''firefox -P "OSINT" --no-remote'';
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
      mimeType = [ "text/html" "text/xml" ];
    };
  };

  programs.firefox ={
    policies =  {
      ExtensionSettings = {
        # ── Cookie Editor ──────────────────────────
        "cookie-editor@cgagnier.ca" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/cookie-editor/latest.xpi";
          private_browsing = false;
        };

        # ── View Page Archive ──────────────────────
        "{6348c3b0-5a5b-11e9-b7df-ebcd13fc1ebb}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/view-page-archive/latest.xpi";
          private_browsing = false;
        };

        # ── HackTools ──────────────────────────────
        "{f1423c11-a4e2-4709-a0f8-6d6a68c83d08}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/hacktools/latest.xpi";
          private_browsing = false;
        };

        # ── Retire.js ──────────────────────────────
        "@retire.js" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/retire-js/latest.xpi";
          private_browsing = false;
        };

        # ── DotGit ─────────────────────────────────
        "{84cbda23-345f-4e74-9695-9a52b9599dc0}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/dotgit/latest.xpi";
          private_browsing = false;
        };

        # ── wappalyzer ─────────────────────────────
        "wappalyzer@crunchlabz.com" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/latest.xpi";
          private_browsing = false;
        };
      };
    };
    profiles = lib.mkDefault {
      "default" = {
        isDefault = true;
        id = 0;
        name = "Default";
      };
      "redteam" = {
        id = 1;
        name = "Red Team";
        userChrome = ''

        ''; # The way firefox looks
        search = {
          default = "ddg";
          privateDefault = "ddg";
          force = true;
          engines ={
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

            bing.metaData.hidden = true;
            google.metaData.alias = "@g";
          };
          order = [
            "ddg"
            "google"
          ];
        };
        settings ={
          "extensions.autoDisableScopes" = 0;
          "browser.privatebrowsing.autostart" = true;
        };
        bookmarks ={
          settings = builtins.fromJSON (builtins.readFile "${config.home.homeDirectory}/.dotfiles/assets/tools/bookmarks-redteam.json");
          force = true;
        };
        extensions = {
          settings = {
            # ublock-origin = {
            #   force = true;
            # };
          };
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
      "OSINT" = {
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

            bing.metaData.hidden = true;
            google.metaData.alias = "@g";
          };
          order = [
            "ddg"
            "google"
          ];
        };
        settings ={
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
    };
  };
}