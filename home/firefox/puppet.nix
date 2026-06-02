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
      "network.proxy.type"              = 1;
      "network.proxy.socks"             = "127.0.0.1";
      "network.proxy.socks_port"        = 1080;
      "network.proxy.socks_version"     = 5;
      "network.proxy.socks_remote_dns"  = true;
      "network.proxy.failover_direct"   = false;

      # ── HTTPS only ────────────────────────────────────────────
      "dom.security.https_only_mode"              = true;
      "dom.security.https_only_mode_ever_enabled" = true;

      # ── Fingerprinting — targeted only (RFP conflicts with UA switcher) ──
      "privacy.fingerprintingProtection"                    = true;
      "privacy.trackingprotection.enabled"                  = true;
      "privacy.trackingprotection.socialtracking.enabled"   = true;
      "privacy.trackingprotection.fingerprinting.enabled"   = true;
      "privacy.trackingprotection.cryptomining.enabled"     = true;

      # ── Cookie isolation — complements Multi-Account Containers ─
      "network.cookie.cookieBehavior" = 5;

      # ── WebRTC + geolocation ───────────────────────────────────
      "media.peerconnection.enabled" = false;
      "geo.enabled"                  = false;

      # ── No speculative requests ────────────────────────────────
      "network.dns.disablePrefetch"             = true;
      "network.prefetch-next"                   = false;
      "network.predictor.enabled"               = false;
      "network.http.speculative-parallel-limit" = 0;

      # ── Safe browsing ──────────────────────────────────────────
      "browser.safebrowsing.malware.enabled"  = true;
      "browser.safebrowsing.phishing.enabled" = true;

      # ── Telemetry ─────────────────────────────────────────────
      "datareporting.healthreport.uploadEnabled"   = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "toolkit.telemetry.unified"                  = false;
      "browser.ping-centre.telemetry"              = false;

      # ── Storage ───────────────────────────────────────────────
      "signon.rememberSignons"          = false;
      "browser.formfill.enable"         = false;
      "media.autoplay.default"          = 5;
      "browser.download.useDownloadDir" = false;
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