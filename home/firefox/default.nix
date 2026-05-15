{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    ./redteam.nix
    ./osint.nix
    ./puppet.nix
    ./theme.nix
  ];

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
      categories = [ "X-AnNIXion-Delivery-Proxy" "X-AnNIXion-Internet" "Network" "WebBrowser" ];
      mimeType = [ "text/html" "text/xml" ];
    };
    firefox-osint = {
      name = "Firefox - OSINT";
      icon = "${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-yellow.png";
      genericName = "Search Browser";
      exec = ''firefox -P "OSINT" --no-remote'';
      terminal = false;
      categories = [ "X-AnNIXion-Recon-OSINT" "X-AnNIXion-Internet" "Network" "WebBrowser" ];
      mimeType = [ "text/html" "text/xml" ];
    };
    firefox-puppet = {
      name = "Firefox - Puppet Master";
      icon = "${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-green.png";
      genericName = "Persona Browser";
      exec = ''firefox -P "Puppet Master" --no-remote'';
      terminal = false;
      categories = [ "X-AnNIXion-Recon-OSINT" "X-AnNIXion-Internet" "Network" "WebBrowser" ];
      mimeType = [ "text/html" "text/xml" ];
    };
  };

  programs.firefox = {
    policies = {
      ExtensionSettings = {
        "*" = {
          private_browsing = true;
          default_area = "menupanel";
        };

        # ── Cookie Editor ──────────────────────────
        "cookie-editor@cgagnier.ca" = {
          private_browsing = true;
          default_area = "menupanel";
        };

        # ── View Page Archive ──────────────────────
        "{6348c3b0-5a5b-11e9-b7df-ebcd13fc1ebb}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/view-page-archive/latest.xpi";
          private_browsing = true;
        };

        # ── HackTools ──────────────────────────────
        "{f1423c11-a4e2-4709-a0f8-6d6a68c83d08}" = {
          private_browsing = true;
        };

        # ── Retire.js ──────────────────────────────
        "@retire.js" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/retire-js/latest.xpi";
          private_browsing = true;
        };

        # ── DotGit ─────────────────────────────────
        "{84cbda23-345f-4e74-9695-9a52b9599dc0}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/dotgit/latest.xpi";
          private_browsing = true;
        };

        # ── Wappalyzer ─────────────────────────────
        "wappalyzer@crunchlabz.com" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/latest.xpi";
          private_browsing = true;
        };
      };
    };
    profiles."default" = {
      isDefault = true;
      id = 0;
      name = "Default";
    };
  };
}