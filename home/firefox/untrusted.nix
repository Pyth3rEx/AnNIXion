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
  programs.firefox.profiles."untrusted" = {
    id = 0;
    isDefault = true;
    name = "Unsafe Browser";
    settings = {
      "extensions.autoDisableScopes" = 0;
      "network.proxy.type" = 0;

      # ── HTTPS only ────────────────────────────────────────────
      "dom.security.https_only_mode"               = true;
      "dom.security.https_only_mode_ever_enabled"  = true;

      # ── Fingerprinting resistance ──────────────────────────────
      # RFP: spoofs window size, timezone (→ UTC), locale, canvas,
      # fonts, and many other surfaces used to fingerprint browsers.
      "privacy.resistFingerprinting"        = true;
      "privacy.fingerprintingProtection"    = true;

      # ── Enhanced tracking protection — strict ──────────────────
      "privacy.trackingprotection.enabled"                  = true;
      "privacy.trackingprotection.socialtracking.enabled"   = true;
      "privacy.trackingprotection.fingerprinting.enabled"   = true;
      "privacy.trackingprotection.cryptomining.enabled"     = true;

      # ── Cookie isolation (Total Cookie Protection) ─────────────
      # Partitions cookie jars per site — cross-site tracking broken
      # without blocking cookies outright.
      "network.cookie.cookieBehavior" = 5;

      # ── WebRTC — disable to prevent IP leaks ──────────────────
      "media.peerconnection.enabled" = false;

      # ── Geolocation ───────────────────────────────────────────
      "geo.enabled" = false;

      # ── Prefetching — disable speculative requests ─────────────
      "network.dns.disablePrefetch"    = true;
      "network.prefetch-next"          = false;
      "network.predictor.enabled"      = false;
      "network.http.speculative-parallel-limit" = 0;

      # ── Safe browsing — keep on for clearnet protection ────────
      "browser.safebrowsing.malware.enabled"  = true;
      "browser.safebrowsing.phishing.enabled" = true;

      # ── Telemetry ─────────────────────────────────────────────
      "datareporting.healthreport.uploadEnabled"       = false;
      "datareporting.policy.dataSubmissionEnabled"     = false;
      "toolkit.telemetry.unified"                      = false;
      "browser.ping-centre.telemetry"                  = false;

      # ── No credential or form storage ─────────────────────────
      "signon.rememberSignons"    = false;
      "browser.formfill.enable"   = false;

      # ── Autoplay blocked ──────────────────────────────────────
      "media.autoplay.default" = 5;

      # ── Always prompt for download location ───────────────────
      "browser.download.useDownloadDir" = false;
    };
    extensions = {
      packages = with addons; [
        ublock-origin    # ad + malware blocking
        canvasblocker    # canvas/WebGL fingerprinting protection
        privacy-badger   # tracker blocking
      ];
    };
  };
}
