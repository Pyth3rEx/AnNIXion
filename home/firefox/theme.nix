{ lib, pkgs, ... }:

let
  shyfox = pkgs.fetchFromGitHub {
    owner = "Naezr";
    repo  = "ShyFox";
    rev   = "aaec12fb0e88eb422467bc84276991ca564de82b";
    hash  = lib.fakeHash;
    # Replace lib.fakeHash with the real hash after your first failed build:
    # sudo nixos-rebuild switch --flake .#AnNIXion --impure
    # Copy the "got:" value from the error and paste it here.
  };

  # Builds a copy of the ShyFox module directory with a patched accent color.
  patchAccent = accent: pkgs.runCommand "shyfox-modules" { } ''
    cp -r ${shyfox}/chrome/ShyFox $out
    chmod -R +w $out
    sed -i 's/--shy-accent-color:.*$/--shy-accent-color: ${accent};/' $out/shy-variables.css
  '';
in
{
  # ── RedTeam — black and red ────────────────────────────────────────────────
  programs.firefox.profiles."redteam" = {
    settings = {
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      "svg.context-properties.content.enabled" = true;
    };
    userChrome  = builtins.readFile "${shyfox}/chrome/userChrome.css";
    userContent = builtins.readFile "${shyfox}/chrome/userContent.css";
  };

  home.file.".mozilla/firefox/redteam/chrome/ShyFox".source = patchAccent "#cc0000";
  home.file.".mozilla/firefox/redteam/chrome/icons".source  = "${shyfox}/chrome/icons";

  # ── OSINT — amber / yellow ─────────────────────────────────────────────────
  programs.firefox.profiles."osint" = {
    settings = {
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      "svg.context-properties.content.enabled" = true;
    };
    userChrome  = builtins.readFile "${shyfox}/chrome/userChrome.css";
    userContent = builtins.readFile "${shyfox}/chrome/userContent.css";
  };

  home.file.".mozilla/firefox/osint/chrome/ShyFox".source = patchAccent "#f5a623";
  home.file.".mozilla/firefox/osint/chrome/icons".source  = "${shyfox}/chrome/icons";
}