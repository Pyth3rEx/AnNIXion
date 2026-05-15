{ inputs, ... }:

let
  shyfox = inputs.shyfox;

  shySettings = {
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "svg.context-properties.content.enabled"             = true;
  };

  # Reads ShyFox's userChrome and appends an accent color override.
  # CSS custom properties are cascade-ordered — our :root rule wins
  # because it appears after all @imports in the file.
  shyChrome = accent: (builtins.readFile "${shyfox}/chrome/userChrome.css") + ''

    :root, ::backdrop {
      --shy-accent-color: ${accent};
    }
  '';

  shyContent = builtins.readFile "${shyfox}/chrome/userContent.css";
in
{
  # ── Red Team — red ────────────────────────────────────────────────
  programs.firefox.profiles."redteam".settings    = shySettings;
  programs.firefox.profiles."redteam".userChrome  = shyChrome "#cc0000";
  programs.firefox.profiles."redteam".userContent = shyContent;
  home.file.".mozilla/firefox/redteam/chrome/ShyFox".source = "${shyfox}/chrome/ShyFox";
  home.file.".mozilla/firefox/redteam/chrome/icons".source  = "${shyfox}/chrome/icons";

  # ── OSINT — amber ─────────────────────────────────────────────────
  programs.firefox.profiles."osint".settings    = shySettings;
  programs.firefox.profiles."osint".userChrome  = shyChrome "#f5a623";
  programs.firefox.profiles."osint".userContent = shyContent;
  home.file.".mozilla/firefox/osint/chrome/ShyFox".source = "${shyfox}/chrome/ShyFox";
  home.file.".mozilla/firefox/osint/chrome/icons".source  = "${shyfox}/chrome/icons";

  # ── Puppet Master — green ─────────────────────────────────────────
  programs.firefox.profiles."puppet".settings    = shySettings;
  programs.firefox.profiles."puppet".userChrome  = shyChrome "#00c853";
  programs.firefox.profiles."puppet".userContent = shyContent;
  home.file.".mozilla/firefox/puppet/chrome/ShyFox".source = "${shyfox}/chrome/ShyFox";
  home.file.".mozilla/firefox/puppet/chrome/icons".source  = "${shyfox}/chrome/icons";
}