# Red Team profile — Burp interception set at profile level, web tooling.
{
  inputs,
  config,
  lib,
  pkgs,
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

        exploit-db = {
          name = "Exploit-DB";
          urls = [ { template = "https://www.exploit-db.com/search?q={searchTerms}"; } ];
          iconMapObj."16" = "https://www.exploit-db.com/favicon.ico";
          definedAliases = [ "@edb" ];
        };

        cve = {
          name = "CVE Search";
          urls = [ { template = "https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword={searchTerms}"; } ];
          definedAliases = [ "@cve" ];
        };

        nvd = {
          name = "NVD";
          urls = [ { template = "https://nvd.nist.gov/vuln/search/results?query={searchTerms}"; } ];
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

      # ── Burp — profile-level proxy (#25) ───────────────────────
      # Native, so interception survives an addon being disabled.
      "network.proxy.type" = 1;
      "network.proxy.http" = "127.0.0.1";
      "network.proxy.http_port" = 8080;
      "network.proxy.ssl" = "127.0.0.1";
      "network.proxy.ssl_port" = 8080;
      "network.proxy.share_proxy_settings" = true;
      # Intercept localhost targets too — testing local apps is routine.
      "network.proxy.allow_hijacking_localhost" = true;
      "network.proxy.no_proxies_on" = "";
      # Fail rather than connect directly when Burp is down.
      "network.proxy.failover_direct" = false;
      # Burp resolves hostnames, so Firefox must not resolve them itself.
      "network.proxy.proxy_over_tls" = false;

      # ── DNS over HTTPS ─────────────────────────────────────────
      # bootstrapAddr pins the resolver's IP or mode 3 deadlocks; the
      # pre-89 spelling is ignored. Unfiltered Quad9 (docs/usage.md#dns).
      "network.trr.mode" = 3;
      "network.trr.uri" = "https://dns10.quad9.net/dns-query";
      "network.trr.bootstrapAddr" = "9.9.9.10";
      "network.dns.skipTRR-when-parental-control-enabled" = false;

      # ── WebRTC + geolocation ───────────────────────────────────
      "media.peerconnection.enabled" = false;
      "geo.enabled" = false;

      # ── No speculative requests during testing ─────────────────
      "network.dns.disablePrefetch" = true;
      "network.prefetch-next" = false;
      "network.predictor.enabled" = false;
      "network.http.speculative-parallel-limit" = 0;

      # ── Telemetry ─────────────────────────────────────────────
      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "toolkit.telemetry.unified" = false;
      "browser.ping-centre.telemetry" = false;

      # ── Storage ───────────────────────────────────────────────
      "signon.rememberSignons" = false;
      "browser.formfill.enable" = false;
      "media.autoplay.default" = 5;
      "browser.download.useDownloadDir" = false;
    };
    bookmarks = {
      settings = builtins.fromJSON (builtins.readFile ../../assets/tools/bookmarks-redteam.json);
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

  programs.firefox.policies.Certificates.Install = [
    "${config.home.homeDirectory}/.dotfiles/assets/certs/burp-ca.pem"
  ];

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
    "${foxyproxy-standard.addonId}" = {
      private_browsing = true;
    };
    "${single-file.addonId}" = {
      private_browsing = true;
    };
    "${hacktools.addonId}" = {
      private_browsing = true;
    };
    "${cookie-editor.addonId}" = {
      private_browsing = true;
    };
  };

  # ── FoxyProxy — shipped, seeded, switched off ────────────────────
  # For ad-hoc work only; the entry below is an example, not a route.
  # Enabling it overrides network.proxy.* wholesale, failover_direct
  # included. See "Red Team — Burp Suite setup" in docs/usage.md.
  programs.firefox.policies."3rdparty".Extensions."${addons.foxyproxy-standard.addonId}" = {
    mode = "disabled";
    sync = false;
    autoBackup = false;
    passthrough = "";
    theme = "";
    container = { };
    commands = {
      setProxy = "";
      setTabProxy = "";
      includeHost = "";
      excludeHost = "";
    };
    data = [
      {
        active = false;
        title = "Burpsuite (example — profile prefs do the real work)";
        type = "http";
        hostname = "127.0.0.1";
        port = "8080";
        username = "";
        password = "";
        cc = "";
        city = "";
        color = "#b22222";
        pac = "";
        pacString = "";
        proxyDNS = true;
        include = [ ];
        exclude = [ ];
        tabProxy = [ ];
      }
    ];
  };
}
