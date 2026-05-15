{ ... }:

let
  nordCSS = accent: ''
    :root {
      --ann-accent: ${accent};
    }

    /* Selected tab — accent line */
    .tabbrowser-tab[selected] .tab-line {
      background-color: var(--ann-accent) !important;
      height: 2px !important;
    }

    /* Nav bar — accent top border identifies the profile at a glance */
    #nav-bar {
      border-top: 2px solid var(--ann-accent) !important;
    }

    /* URL bar — accent ring on focus */
    #urlbar:focus-within #urlbar-background {
      border-color: var(--ann-accent) !important;
      box-shadow: 0 0 0 1px var(--ann-accent), 0 1px 3px rgba(0, 0, 0, 0.4) !important;
    }

    /* Remove Firefox Account button */
    #fxa-toolbar-menu-button {
      display: none !important;
    }

    /* Developer button — left separator marks the start of the technical area */
    #developer-button {
      border-inline-start: 1px solid color-mix(in srgb, currentColor 25%, transparent) !important;
      margin-inline-start: 4px !important;
      padding-inline-start: 2px !important;
    }
  '';

  puppetCSS = accent: (nordCSS accent) + ''

    /* Container tab stripe — taller and fully opaque so identity is always visible */
    .tab-context-line {
      height: 4px !important;
      opacity: 1 !important;
    }
  '';

  nordSettings = {
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "svg.context-properties.content.enabled"             = true;
    "browser.uiCustomization.state" = builtins.toJSON {
      placements = {
        "widget-overflow-fixed-list" = [];
        "nav-bar" = [
          "back-button"
          "forward-button"
          "stop-reload-button"
          "urlbar-container"
          "downloads-button"
          "developer-button"
          "unified-extensions-button"
        ];
        "toolbar-menubar"  = [ "menubar-items" ];
        "TabsToolbar"      = [ "tabbrowser-tabs" "new-tab-button" "alltabs-button" ];
        "PersonalToolbar"  = [ "personal-bookmarks" ];
      };
      seen = [
        "developer-button"
        "fxa-toolbar-menu-button"
        "unified-extensions-button"
        "downloads-button"
      ];
      dirtyAreaCache = [ "nav-bar" "TabsToolbar" "toolbar-menubar" "PersonalToolbar" ];
      currentVersion = 20;
      newElementCount = 2;
    };
  };
in
{
  # ── Red Team — Nord Aurora red ───────────────────────────────────
  programs.firefox.profiles."redteam".settings   = nordSettings;
  programs.firefox.profiles."redteam".userChrome = nordCSS "#bf616a";

  # ── OSINT — Nord Aurora yellow ───────────────────────────────────
  programs.firefox.profiles."osint".settings   = nordSettings;
  programs.firefox.profiles."osint".userChrome = nordCSS "#ebcb8b";

  # ── Puppet Master — Nord Aurora green + prominent container strip ─
  programs.firefox.profiles."puppet".settings   = nordSettings;
  programs.firefox.profiles."puppet".userChrome = puppetCSS "#a3be8c";
}
