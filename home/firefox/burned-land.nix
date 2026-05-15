{ pkgs }:

let
  addonId = "burned-land@annixion";

  manifest = pkgs.writeText "manifest.json" (builtins.toJSON {
    manifest_version = 2;
    name = "Burned Land";
    version = "1.0.0";
    description = "One click: wipe all session data and open a clean slate.";
    permissions = [ "browsingData" "tabs" ];
    browser_action = {
      default_title = "Burned Land — scorched earth";
      default_icon = { "16" = "icon.svg"; "32" = "icon.svg"; };
    };
    background = {
      scripts = [ "background.js" ];
      persistent = false;
    };
    browser_specific_settings.gecko.id = addonId;
  });

  icon = pkgs.writeText "icon.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
      <path fill="#ffd000" d="
        M8 1C6.5 3.5 5 6 6 8.5c.3.8-.1 1.5-.8 1.5C4 10 3.2 8 4 6
        C2.2 7.5 2 10 3 12c1 2.2 3 3.5 5 3.5s4-1.3 5-3.5c1-2 .8-4.5-.5-6.5
        C12 7 11 8 9.5 8.5c.5-2-.5-5-1.5-7.5z
      "/>
      <circle fill="#ffd000" opacity=".5" cx="8" cy="11" r="2"/>
    </svg>
  '';

  background = pkgs.writeText "background.js" ''
    browser.browserAction.onClicked.addListener(async () => {
      await browser.browsingData.remove({}, {
        cache:          true,
        cookies:        true,
        downloads:      true,
        formData:       true,
        history:        true,
        localStorage:   true,
        serviceWorkers: true,
        indexedDB:      true,
      });

      const allTabs = await browser.tabs.query({ currentWindow: true });
      const freshTab = await browser.tabs.create({ url: "about:newtab" });
      const toClose = allTabs.map(t => t.id).filter(id => id !== freshTab.id);
      if (toClose.length > 0) {
        await browser.tabs.remove(toClose);
      }
    });
  '';
in

pkgs.stdenv.mkDerivation {
  pname   = "burned-land";
  version = "1.0.0";

  passthru = { inherit addonId; };

  dontUnpack  = true;
  buildInputs = [ pkgs.zip ];

  buildPhase = ''
    mkdir ext
    cp ${manifest}   ext/manifest.json
    cp ${icon}       ext/icon.svg
    cp ${background} ext/background.js
    cd ext && zip -r ../burned-land.xpi . && cd ..
  '';

  installPhase = ''
    ffid="{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
    mkdir -p "$out/share/mozilla/extensions/$ffid"
    install -m644 burned-land.xpi "$out/share/mozilla/extensions/$ffid/${addonId}.xpi"
  '';
}
