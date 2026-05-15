{ inputs, pkgs, ... }:

let
  repoRoot          = inputs.firefox-addons.sourceInfo.outPath;
  libMozilla        = import "${repoRoot}/lib/mozilla.nix" { lib = pkgs.lib; };
  buildMozillaXpi   = libMozilla.mkBuildMozillaXpiAddon { inherit (pkgs) fetchurl stdenv; };
  addons = import "${inputs.firefox-addons}" {
    buildMozillaXpiAddon = buildMozillaXpi;
    inherit (pkgs) fetchurl lib stdenv;
  };

  # Firefox browser-action widget ID convention: "<addonId>-browser-action"
  widget = addon: "${addon.addonId}-browser-action";

  # CSS-escape an addon widget ID for use as an ID selector.
  # Firefox element IDs follow the raw addonId pattern; special characters
  # (@, {, }, .) must be escaped in CSS selectors with a leading backslash.
  cssId = addon:
    let
      id = widget addon;
      escaped = builtins.replaceStrings
        [ "@"  "{"  "}"  "." ]
        [ "\\@" "\\{" "\\}" "\\." ]
        id;
    in "#${escaped}";

  # ── Per-profile Nord + neon CSS ───────────────────────────────────
  # accent      — the neon highlight color for this profile
  # techAnchor  — CSS selector for the first button in the technical area;
  #               receives the left separator that marks the section start
  nordCSS = { accent, techAnchor }: ''
    :root {
      --ann-nord0:  #2e3440;
      --ann-nord1:  #3b4252;
      --ann-nord2:  #434c5e;
      --ann-nord3:  #4c566a;
      --ann-nord4:  #d8dee9;
      --ann-accent: ${accent};
      --ann-glow:   color-mix(in srgb, var(--ann-accent) 35%, transparent);
    }

    /* ── Toolbar backgrounds ─────────────────────────────────────── */
    #navigator-toolbox {
      background-color: var(--ann-nord0) !important;
    }

    #TabsToolbar {
      background-color: var(--ann-nord0) !important;
      padding-block: 2px !important;
    }

    #nav-bar {
      background-color: var(--ann-nord1) !important;
      border-top: 2px solid var(--ann-accent) !important;
      /* Neon bleed — accent glow bleeds down into the page */
      box-shadow: 0 2px 10px var(--ann-glow) !important;
    }

    /* ── Tabs ────────────────────────────────────────────────────── */
    .tabbrowser-tab:not([selected]):hover .tab-background {
      background-color: var(--ann-nord2) !important;
      border-radius: 4px 4px 0 0 !important;
    }

    .tabbrowser-tab[selected] .tab-background {
      background-color: var(--ann-nord1) !important;
      border-radius: 4px 4px 0 0 !important;
    }

    .tabbrowser-tab[selected] .tab-line {
      background-color: var(--ann-accent) !important;
      height: 2px !important;
      box-shadow: 0 0 8px var(--ann-accent) !important;
    }

    /* ── URL bar ─────────────────────────────────────────────────── */
    #urlbar-background {
      background-color: var(--ann-nord0) !important;
      border: 1px solid var(--ann-nord3) !important;
      border-radius: 6px !important;
    }

    #urlbar:focus-within #urlbar-background {
      border-color: var(--ann-accent) !important;
      box-shadow: 0 0 0 1px var(--ann-accent),
                  0 0 12px var(--ann-glow) !important;
    }

    /* ── Toolbar button hover — icon glows in accent ─────────────── */
    .toolbarbutton-1:hover:not([disabled]) {
      background-color: var(--ann-nord2) !important;
      border-radius: 4px !important;
    }

    .toolbarbutton-1:hover:not([disabled]) .toolbarbutton-icon {
      fill:   var(--ann-accent) !important;
      color:  var(--ann-accent) !important;
      filter: drop-shadow(0 0 4px var(--ann-accent)) !important;
    }

    /* ── Remove Firefox Account button ───────────────────────────── */
    #fxa-toolbar-menu-button {
      display: none !important;
    }

    /* ── Technical area — left separator marks the section start ─── */
    ${techAnchor} {
      border-inline-start: 1px solid var(--ann-nord3) !important;
      margin-inline-start: 6px !important;
      padding-inline-start: 4px !important;
    }
  '';

  # ── Toolbar layout ─────────────────────────────────────────────────
  # navBarExtras: list of extension widget IDs to pin between the URL bar
  # and the developer button (the "technical area").
  makeSettings = navBarExtras: {
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
        ] ++ navBarExtras ++ [
          "developer-button"
          "unified-extensions-button"
        ];
        "toolbar-menubar" = [ "menubar-items" ];
        "TabsToolbar"     = [ "tabbrowser-tabs" "new-tab-button" "alltabs-button" ];
        "PersonalToolbar" = [ "personal-bookmarks" ];
      };
      seen = [
        "developer-button"
        "fxa-toolbar-menu-button"
        "unified-extensions-button"
        "downloads-button"
      ] ++ navBarExtras;
      dirtyAreaCache = [ "nav-bar" "TabsToolbar" "toolbar-menubar" "PersonalToolbar" ];
      currentVersion = 20;
      newElementCount = 2;
    };
  };
in
{
  # ── Red Team — neon crimson (#ff2244) ────────────────────────────
  # FoxyProxy and HackTools pinned to toolbar; technical area starts at FoxyProxy.
  programs.firefox.profiles."redteam".settings   = makeSettings [
    (widget addons.foxyproxy-standard)
    (widget addons.hacktools)
  ];
  programs.firefox.profiles."redteam".userChrome = nordCSS {
    accent     = "#ff2244";
    techAnchor = cssId addons.foxyproxy-standard;
  };

  # ── OSINT — neon amber (#ffd000) ─────────────────────────────────
  programs.firefox.profiles."osint".settings   = makeSettings [];
  programs.firefox.profiles."osint".userChrome = nordCSS {
    accent     = "#ffd000";
    techAnchor = "#developer-button";
  };

  # ── Puppet Master — neon green (#00e676) ─────────────────────────
  programs.firefox.profiles."puppet".settings   = makeSettings [];
  programs.firefox.profiles."puppet".userChrome = (nordCSS {
    accent     = "#00e676";
    techAnchor = "#developer-button";
  }) + ''

    /* ── Container identity stripe (Puppet Master only) ─────────── */
    /* Always-visible 4px strip so the active container identity is
       immediately obvious even at a glance across many tabs. */
    .tab-context-line {
      height:  4px !important;
      opacity: 1 !important;
    }
  '';
}
