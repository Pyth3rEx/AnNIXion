# home.nix — the operator user's environment.
# All mkDefault, so user/home.nix wins without lib.mkForce.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  SlotIcons = pkgs.stdenvNoCC.mkDerivation {
    name = "Slot-Nord-Dark-Icons";
    src = pkgs.fetchFromGitHub {
      owner = "L4ki";
      repo = "Slot-Plasma-Themes";
      rev = "4dd93ad62cf47307d85e3a624eacba34578bf1fe";
      sha256 = "sha256-M2jCyPLPDqhF2KnovRIrsISOECpFgaR4TUI0N++P8ho=";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/icons
      cp -r "Slot Icons Themes/." $out/share/icons
    '';
  };

  # ── TiledMenu tile layout ────────────────────────────────────────────────
  # Group header + 2×2 tiles, 3 per row, keyed on home/apps-menu.nix IDs.
  tileGroups = [
    {
      label = "01. Reconnaissance";
      apps = [
        "annixion-theharvester"
        "annixion-whois"
        "annixion-dig"
        "annixion-whatweb"
        "annixion-nmap"
        "annixion-gobuster"
        "annixion-ffuf"
        "annixion-gqrx"
        "annixion-gnuradio"
        "annixion-hackrf"
      ];
    }
    {
      label = "02. Weaponization";
      apps = [
        "annixion-ghidra"
        "annixion-binwalk"
      ];
    }
    {
      label = "03. Delivery";
      apps = [
        "annixion-burpsuite"
        "annixion-sqlmap"
      ];
    }
    {
      label = "04. Exploitation";
      apps = [
        "annixion-metasploit"
        "annixion-john"
        "annixion-hashcat"
        "annixion-hydra"
        "annixion-seclists"
        "annixion-aircrack"
      ];
    }
    {
      label = "05. Installation & C2";
      apps = [
        "annixion-netcat"
      ];
    }
    {
      label = "06. Post-Exploitation";
      apps = [
        "annixion-impacket"
      ];
    }
    {
      label = "07. Forensics & RE";
      apps = [
        "annixion-volatility"
        "annixion-autopsy"
        "annixion-wireshark"
      ];
    }
    {
      label = "Tools";
      apps = [
        "annixion-vscodium"
        "annixion-github-desktop"
        "annixion-obsidian"
        "annixion-onlyoffice"
      ];
    }
    {
      label = "System";
      apps = [
        "annixion-konsole"
        "annixion-dolphin"
        "annixion-systemsettings"
        "annixion-kleopatra"
        "annixion-htop"
      ];
    }
  ];

  generateTileModel =
    groups:
    let
      foldGroup =
        acc: group:
        let
          n = builtins.length group.apps;
          numRows = if n == 0 then 0 else (n + 2) / 3;
          groupTile = {
            tileType = "group";
            inherit (group) label;
            url = "";
            x = 0;
            inherit (acc) y;
            w = 6;
            h = 1;
          };
          appTiles = lib.imap0 (i: app: {
            url = "${app}.desktop";
            x = (lib.mod i 3) * 2;
            y = acc.y + 1 + (i / 3) * 2;
            w = 2;
            h = 2;
          }) group.apps;
        in
        {
          tiles = acc.tiles ++ [ groupTile ] ++ appTiles;
          y = acc.y + 1 + numRows * 2;
        };
      result = builtins.foldl' foldGroup {
        tiles = [ ];
        y = 0;
      } groups;
    in
    result.tiles;

  tileModelFile = pkgs.writeText "tiledmenu-tilemodel.json" (
    builtins.toJSON (generateTileModel tileGroups)
  );

  TiledMenu = pkgs.stdenvNoCC.mkDerivation {
    pname = "plasma-applet-tiledmenu";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "Zren";
      repo = "plasma-applet-tiledmenu";
      rev = "master";
      hash = "sha256-noWH4bRyB/7v2K8jbj8ZD+5klUt4zOWiFZCEVdNmDL4=";
    };
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      dest=$out/share/plasma/plasmoids/com.github.zren.tiledmenu
      mkdir -p "$out/share/plasma/plasmoids"

      cp -rT ./package "$dest"

      if ! [ -f "$dest/metadata.json" ]; then
        echo "ERROR: metadata.json missing after install — source was empty or wrong layout" >&2
        exit 1
      fi
      runHook postInstall
    '';
  };
in
{
  imports = [
    ./home/firefox
    ./home/plasma.nix
    ./home/vscodium.nix
    ./home/only-office.nix
    ./home/apps-menu.nix
    ./home/control-center.nix
    ./home/fastfetch.nix
    ./home/zsh.nix
    ./home/file-visibility.nix
    ./home/konsole.nix
  ];

  home.username = lib.mkDefault "operator";
  home.homeDirectory = lib.mkDefault "/home/operator";

  # Like system.stateVersion — never change this.
  home.stateVersion = "26.05";

  programs.home-manager.enable = lib.mkDefault true;

  # Symlink so KDE picks the icon theme up.
  xdg.dataFile."icons".source = "${SlotIcons}/share/icons";

  # ── User packages ─────────────────────────────────────────
  # Offensive/OSINT/SDR tooling is system-wide, in modules/security-tools.nix.
  home.packages = with pkgs; [
    # ── Terminal & shell ──────────────────────────────────────
    zsh

    # ── Development ───────────────────────────────────────────
    gh
    github-desktop
    python3
    python3Packages.pip

    # ── Utilities ─────────────────────────────────────────────
    ripgrep
    fd
    bat
    # fzf is managed by programs.fzf in home/zsh.nix
    jq
    unzip
    p7zip
    file
    inetutils
    wirelesstools
    net-tools
    dnsmasq
    lftp
    git
    wget
    curl
    htop
    tree
    act

    # ── Productivity ──────────────────────────────────────────
    obsidian
    kdePackages.kleopatra

    # ── Fonts ─────────────────────────────────────────────────
    kdePackages.fcitx5-qt

    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji

    # ── Icons & cursors ───────────────────────────────────────
    SlotIcons
    nordzy-cursor-theme

    # ── Plasma widgets ────────────────────────────────────────
    TiledMenu

    # ── Color engines ─────────────────────────────────────────
    chroma # needed by the oh-my-zsh "colorize" plugin
  ];

  services = {
    gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
      defaultCacheTtl = 1800;
      maxCacheTtl = 7200;
      enableSshSupport = true;
    };
  };

  home.activation.onlyofficeFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.local/share/fonts"

    cp -rf ${pkgs.noto-fonts}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true

    cp -rf ${pkgs.noto-fonts-cjk-sans}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true

    cp -rf ${pkgs.noto-fonts-cjk-serif}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true

    cp -rf ${pkgs.noto-fonts-color-emoji}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true
  '';

  # ── TiledMenu install & configuration ─────────────────────
  # Plasma only scans ~/.local/share/plasma/plasmoids/ at session start.
  home.activation.installTiledMenu = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _tm="$HOME/.local/share/plasma/plasmoids/com.github.zren.tiledmenu"
    [ -d "$_tm" ] && $DRY_RUN_CMD chmod -R u+w "$_tm"
    $DRY_RUN_CMD rm -rf "$_tm"
    $DRY_RUN_CMD mkdir -p "$HOME/.local/share/plasma/plasmoids"
    $DRY_RUN_CMD cp -rL \
      "${TiledMenu}/share/plasma/plasmoids/com.github.zren.tiledmenu" \
      "$_tm"
    $DRY_RUN_CMD chmod -R u+w "$_tm"
  '';

  # plasma-manager cannot reach a third-party widget's dynamic applet ID,
  # so find it in the file it writes and set the keys directly.
  home.activation.configureTiledMenu = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _log="/tmp/annixion-tiledmenu.log"
    _plasmarc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    echo "=== configureTiledMenu $(date) ===" > "$_log"

    if [ ! -f "$_plasmarc" ]; then
      echo "plasma config not found" >> "$_log"
    else
      _section=$(${pkgs.gawk}/bin/awk '/^\[/ { sec=$0 } /^plugin=com\.github\.zren\.tiledmenu$/ { print sec; exit }' "$_plasmarc")
      echo "section: $_section" >> "$_log"

      if [ -z "$_section" ]; then
        echo "TiledMenu applet not found; plugins present:" >> "$_log"
        ${pkgs.gnugrep}/bin/grep "^plugin=" "$_plasmarc" >> "$_log" 2>&1
      else
        _c=$(echo "$_section" | ${pkgs.gnused}/bin/sed 's/.*\[Containments\]\[\([0-9]*\)\].*/\1/')
        _a=$(echo "$_section" | ${pkgs.gnused}/bin/sed 's/.*\[Applets\]\[\([0-9]*\)\].*/\1/')
        echo "containment=$_c applet=$_a" >> "$_log"

        if [ -n "$_c" ] && [ "$_c" != "$_section" ] && [ -n "$_a" ] && [ "$_a" != "$_section" ]; then
          _kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
            --file plasma-org.kde.plasma.desktop-appletsrc \
            --group Containments --group $_c --group Applets --group $_a \
            --group Configuration --group General"

          _b64=$(${pkgs.coreutils}/bin/base64 --wrap=0 < "${tileModelFile}")

          $DRY_RUN_CMD $_kw --key defaultAppListView JumpToCategory
          $DRY_RUN_CMD $_kw --key showRecentApps     false
          $DRY_RUN_CMD $_kw --key fixedPanelIcon     true
          $DRY_RUN_CMD $_kw --key icon               "${./assets/icons/AnNIXion.png}"
          $DRY_RUN_CMD $_kw --key tileModel          "$_b64"
          echo "done" >> "$_log"
        else
          echo "could not parse containment/applet from: $_section" >> "$_log"
        fi
      fi
    fi
  '';

  programs = {
    gpg = {
      enable = true;
    };
    # ── Git ─────────────────────────────────────────────────
    # Override userName/userEmail in user/home.nix (see user/examples/git.nix).
    git = {
      settings = {
        enable = lib.mkDefault true;
        userName = lib.mkDefault "CHANGEME";
        userEmail = lib.mkDefault "your@email.com";
        extraConfig = lib.mkDefault {
          init.defaultBranch = "main";
          pull.rebase = false;
        };
      };
    };
  };
}
