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
      "network.proxy.failover_direct" = false;
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

  home.activation.generateBurpCA = lib.hm.dag.entryAfter ["writeBoundary"] ''
    CERT_DIR="${config.home.homeDirectory}/.dotfiles/assets/certs"
    CERT_PEM="$CERT_DIR/burp-ca.pem"

    if [ ! -f "$CERT_PEM" ]; then
      mkdir -p "$CERT_DIR"
      ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 \
        -keyout "$CERT_DIR/burp-ca.key" \
        -out "$CERT_PEM" \
        -days 3650 -nodes \
        -subj "/CN=AnNIXion Burp CA/O=AnNIXion" 2>/dev/null
      ${pkgs.openssl}/bin/openssl x509 -in "$CERT_PEM" -outform DER \
        -out "$CERT_DIR/burp-ca.der"
      ${pkgs.openssl}/bin/openssl pkcs8 -topk8 -nocrypt \
        -in "$CERT_DIR/burp-ca.key" -inform PEM \
        -out "$CERT_DIR/burp-ca-key.der" -outform DER
      chmod 600 "$CERT_DIR/burp-ca.key" "$CERT_DIR/burp-ca-key.der"
    fi
  '';

  programs.firefox.policies.Certificates.Install = [
    "${config.home.homeDirectory}/.dotfiles/assets/certs/burp-ca.pem"
  ];

  programs.firefox.policies.ExtensionSettings = with addons; {
    "${ublock-origin.addonId}"      = { private_browsing = true; };
    "${bitwarden.addonId}"          = { private_browsing = true; };
    "${privacy-badger.addonId}"     = { private_browsing = true; };
    "${darkreader.addonId}"         = { private_browsing = true; };
    "${foxyproxy-standard.addonId}" = { private_browsing = true; };
    "${single-file.addonId}"        = { private_browsing = true; };
    "${hacktools.addonId}"          = { private_browsing = true; };
    "${cookie-editor.addonId}"      = { private_browsing = true; };
  };

  programs.firefox.policies."3rdparty".Extensions."${addons.foxyproxy-standard.addonId}" = {
    mode = "127.0.0.1:8080";
    sync = false;
    autoBackup = false;
    passthrough = "";
    theme = "";
    container = {};
    commands = {
      setProxy = "";
      setTabProxy = "";
      includeHost = "";
      excludeHost = "";
    };
    data = [{
      active = true;
      title = "Burpsuite";
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
      include = [];
      exclude = [];
      tabProxy = [];
    }];
  };
}