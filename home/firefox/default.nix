{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    ./untrusted.nix
    ./redteam.nix
    ./osint.nix
    ./puppet.nix
    ./theme.nix
  ];

  programs.firefox.enable = lib.mkDefault true;

  home.file = {
    ".local/share/applications/firefox.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Firefox
      NoDisplay=true
    '';
    ".local/share/applications/firefox-untrusted.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Firefox - Unsafe Browser
      GenericName=Unsafe Browser
      Icon=${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-grey.png
      Exec=firefox -P "Unsafe Browser" --no-remote
      Terminal=false
      Categories=X-AnNIXion-Internet;Network;WebBrowser;
      MimeType=text/html;text/xml;
    '';
    ".local/share/applications/firefox-red.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Firefox - Red Team
      GenericName=Assault Browser
      Icon=${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-red.png
      Exec=firefox -P "Red Team" --no-remote
      Terminal=false
      Categories=X-AnNIXion-Delivery-Proxy;X-AnNIXion-Internet;Network;WebBrowser;
      MimeType=text/html;text/xml;
    '';
    ".local/share/applications/firefox-osint.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Firefox - OSINT
      GenericName=Search Browser
      Icon=${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-yellow.png
      Exec=firefox -P "OSINT" --no-remote
      Terminal=false
      Categories=X-AnNIXion-Recon-OSINT;X-AnNIXion-Internet;Network;WebBrowser;
      MimeType=text/html;text/xml;
    '';
    ".local/share/applications/firefox-puppet.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Firefox - Puppet Master
      GenericName=Persona Browser
      Icon=${config.home.homeDirectory}/.dotfiles/assets/icons/firefox-green.png
      Exec=firefox -P "Puppet Master" --no-remote
      Terminal=false
      Categories=X-AnNIXion-Recon-OSINT;X-AnNIXion-Internet;Network;WebBrowser;
      MimeType=text/html;text/xml;
    '';
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
  };
}