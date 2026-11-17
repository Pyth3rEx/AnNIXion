{ lib }:
# TiledMenu's tile grid, in the form the applet stores it: base64-encoded
# JSON under the tileModel key. Six columns by nine rows is what the popup
# shows without scrolling, so the whole layout fits in that budget.
let
  # The applet decodes this with Qt.atob, so plain JSON will not load.
  toBase64 = import ../../../catalog/base64.nix { inherit lib; };

  columns = 6;

  # Each group is one header row, two 2×2 hero tiles and a 2×2 block of four
  # icon-only 1×1 tiles — three rows, so three groups fill the popup exactly.
  groups = [
    {
      label = "ENGAGEMENT";
      color = "#a01f1f";
      heroes = [
        "annixion-konsole"
        "annixion-burpsuite"
      ];
      cluster = [
        "annixion-nmap"
        "annixion-sqlmap"
        "annixion-ffuf"
        "annixion-gobuster"
      ];
    }
    {
      label = "ANALYSIS & RE";
      color = "#6e1a1a";
      heroes = [
        "annixion-wireshark"
        "annixion-ghidra"
      ];
      cluster = [
        "annixion-volatility"
        "annixion-autopsy"
        "annixion-binwalk"
        "annixion-hashcat"
      ];
    }
    {
      label = "WORKSPACE";
      color = "#3f1d1d";
      heroes = [
        "annixion-vscodium"
        "annixion-obsidian"
      ];
      cluster = [
        "annixion-dolphin"
        "annixion-kleopatra"
        "annixion-systemsettings"
        "annixion-htop"
      ];
    }
  ];

  groupTiles =
    top: group:
    [
      {
        x = 0;
        y = top;
        w = columns;
        h = 1;
        url = "";
        tileType = "group";
        inherit (group) label;
      }
    ]
    ++ lib.imap0 (i: app: {
      x = i * 2;
      y = top + 1;
      w = 2;
      h = 2;
      url = "${app}.desktop";
      backgroundColor = group.color;
    }) group.heroes
    ++ lib.imap0 (i: app: {
      x = 4 + (lib.mod i 2);
      y = top + 1 + (i / 2);
      w = 1;
      h = 1;
      url = "${app}.desktop";
      backgroundColor = group.color;
      # A 60px tile has no room for a caption under the icon.
      showLabel = false;
    }) group.cluster;

  tiles = lib.concatLists (lib.imap0 (i: group: groupTiles (i * 3) group) groups);
in
toBase64 (builtins.toJSON tiles)
