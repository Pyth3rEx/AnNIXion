# OSINT profile — VPN-enforced, investigation engines and fingerprint evasion.
{
  inputs,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  repoRoot = inputs.firefox-addons.sourceInfo.outPath;
  libMozilla = import "${repoRoot}/lib/mozilla.nix" { inherit (pkgs) lib; };
  buildMozillaXpiAddon = libMozilla.mkBuildMozillaXpiAddon { inherit (pkgs) fetchurl stdenv; };
  addons = import "${inputs.firefox-addons}" {
    inherit buildMozillaXpiAddon;
    inherit (pkgs) fetchurl lib stdenv;
  };
in
{
  programs.firefox.profiles."osint" = lib.mkIf osConfig.annixion.firefox.profiles.osint.enable {
    id = 2;
    name = "OSINT";
    search = {
      default = "ddg";
      privateDefault = "ddg";
      force = true;
      engines = {
        nix-packages = {
          name = "Nix Packages";
          urls = [
            {
              template = "https://search.nixos.org/packages";
              params = [
                {
                  name = "type";
                  value = "packages";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [ "@np" ];
        };

        nixos-wiki = {
          name = "NixOS Wiki";
          urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
          iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
          definedAliases = [ "@nw" ];
        };

        shodan = {
          name = "Shodan";
          urls = [ { template = "https://www.shodan.io/search?query={searchTerms}"; } ];
          iconMapObj."16" = "https://www.shodan.io/favicon.ico";
          definedAliases = [ "@sh" ];
        };

        censys = {
          name = "Censys";
          urls = [ { template = "https://search.censys.io/search?resource=hosts&q={searchTerms}"; } ];
          definedAliases = [ "@cs" ];
        };

        wayback = {
          name = "Wayback Machine";
          urls = [ { template = "https://web.archive.org/web/*/{searchTerms}"; } ];
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

      # ── VPN enforcement ───────────────────────────────────────
      # Egress is confined by system/vpn-enforcement.nix, not by prefs.
      "network.proxy.type" = 0;

      # ── DNS over HTTPS ─────────────────────────────────────────
      # No plaintext fallback. bootstrapAddr pins the resolver's IP or
      # mode 3 deadlocks. Unfiltered Quad9 (docs/usage.md#dns).
      "network.trr.mode" = 3;
      "network.trr.uri" = "https://dns10.quad9.net/dns-query";
      "network.trr.bootstrapAddr" = "9.9.9.10";
      "network.dns.skipTRR-when-parental-control-enabled" = false;
      "network.trr.useGET" = true;

      # ── Encrypted Client Hello ─────────────────────────────────
      # Hides the SNI from anyone on-path; needs the DoH config above.
      "network.dns.echconfig.enabled" = true;
      "network.dns.http3_echconfig.enabled" = true;
      "network.dns.use_https_rr_as_altsvc" = true;
      "security.tls.ech.grease_http3" = true;

      # ── HTTPS only ────────────────────────────────────────────
      "dom.security.https_only_mode" = true;
      "dom.security.https_only_mode_ever_enabled" = true;

      # ── Certificate revocation — CRLite, not OCSP ───────────────
      # CRLite checks revocation from a local, pre-synced list. OCSP would
      # phone the issuing CA on every new cert seen — a leak of exactly
      # what's being investigated — so it's dropped here with CRLite as
      # the backstop. OSINT-only: other profiles keep OCSP's default checks.
      "security.pki.crlite_mode" = 2;
      "security.OCSP.enabled" = 0;
      "security.OCSP.require" = false;

      # ── Fingerprinting ────────────────────────────────────────
      # Full RFP, not just targeted protection: this profile accepts broken
      # WebAuthn/passkey logins in exchange for spoofing OS, platform and
      # timing details wholesale. puppet.nix and untrusted.nix keep
      # targeted-only protection instead, since passkey logins need to keep
      # working there.
      "privacy.resistFingerprinting" = true;
      "privacy.spoof_english" = 2;
      "privacy.fingerprintingProtection" = true;
      "privacy.trackingprotection.enabled" = true;
      "privacy.trackingprotection.socialtracking.enabled" = true;
      "privacy.trackingprotection.fingerprinting.enabled" = true;
      "privacy.trackingprotection.cryptomining.enabled" = true;
      "privacy.socialtracking.block_cookies.enabled" = true;
      "privacy.query_stripping.enabled" = true;

      # ── Referrer ───────────────────────────────────────────────
      # Never leak the previous page to a site under investigation.
      # OSINT-only: other profiles keep the default in case a target's
      # CSRF-gated forms or hotlink protection expect it.
      "network.http.sendRefererHeader" = 0;

      # ── Cookie isolation (Total Cookie Protection) ─────────────
      "network.cookie.cookieBehavior" = 5;

      # ── WebRTC + geolocation ───────────────────────────────────
      "media.peerconnection.enabled" = false;
      "geo.enabled" = false;

      # ── No speculative requests ────────────────────────────────
      "network.dns.disablePrefetch" = true;
      "network.prefetch-next" = false;
      "network.predictor.enabled" = false;
      "network.http.speculative-parallel-limit" = 0;

      # ── Safe browsing ──────────────────────────────────────────
      "browser.safebrowsing.malware.enabled" = true;
      "browser.safebrowsing.phishing.enabled" = true;

      # ── Telemetry ─────────────────────────────────────────────
      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "toolkit.telemetry.unified" = false;
      "browser.ping-centre.telemetry" = false;

      # ── Pinned despite being Firefox defaults today ─────────────
      # Never assume a default holds on an opsec-sensitive profile — pin it.
      "network.http.http3.enable" = true;
      "fission.autostart" = true;
      "gfx.webrender.all" = true;

      # ── No sponsored content ───────────────────────────────────
      "browser.newtabpage.activity-stream.showSponsored" = false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
      "browser.newtabpage.activity-stream.feeds.topsites" = false;
      "browser.newtabpage.activity-stream.system.showSponsored" = false;
      "extensions.pocket.enabled" = false;

      # ── PDF ────────────────────────────────────────────────────
      "pdfjs.enableScripting" = false;

      # ── Storage ───────────────────────────────────────────────
      "signon.rememberSignons" = false;
      "browser.formfill.enable" = false;
      "media.autoplay.default" = 5;
      "browser.download.useDownloadDir" = false;
    };
    bookmarks = {
      settings = builtins.fromJSON (builtins.readFile ../../assets/firefox/bookmarks-osint.json);
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
    "${ublock-origin.addonId}" = {
      private_browsing = true;
    };
    "${bitwarden.addonId}" = {
      private_browsing = true;
    };
    "${privacy-badger.addonId}" = {
      private_browsing = true;
    };
    "${darkreader.addonId}" = {
      private_browsing = true;
    };
    "${noscript.addonId}" = {
      private_browsing = true;
    };
    "${single-file.addonId}" = {
      private_browsing = true;
    };
    "${cookie-autodelete.addonId}" = {
      private_browsing = true;
    };
    "${canvasblocker.addonId}" = {
      private_browsing = true;
    };
    "${user-agent-string-switcher.addonId}" = {
      private_browsing = true;
    };
    "${feedbroreader.addonId}" = {
      private_browsing = true;
    };
  };
}
