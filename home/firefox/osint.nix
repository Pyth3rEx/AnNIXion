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
      "privacy.fingerprintingProtection"               = true;
      "privacy.trackingprotection.enabled"             = true;
      "privacy.trackingprotection.socialtracking.enabled"   = true;
      "privacy.trackingprotection.fingerprinting.enabled"   = true;
      "privacy.trackingprotection.cryptomining.enabled"     = true;

      # ── Cookie isolation (Total Cookie Protection) ─────────────
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
      settings = builtins.fromJSON (builtins.readFile ../../assets/tools/bookmarks-osint.json);
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
  };
}