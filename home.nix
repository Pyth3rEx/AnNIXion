# home.nix
# This file declares everything about YOUR user environment.
# Think of it as your personal layer on top of the system.
# Changes here only affect the "operator" user, not the whole system.
#
# Every option uses lib.mkDefault (priority 1000). That means anything
# you put in user/home.nix at normal priority (100) automatically wins
# without needing lib.mkForce.
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
  # Each entry becomes a group header + 2×2 app tiles arranged 3 per row.
  # Apps reference the .desktop file IDs written by apps-menu.nix.
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
  ];

  # Home Manager needs to know your username and home directory.
  home.username = lib.mkDefault "operator";
  home.homeDirectory = lib.mkDefault "/home/operator";

  # Like system.stateVersion — do not change this ever.
  # It records the Home Manager version you first activated with.
  home.stateVersion = "26.05";

  # Let Home Manager manage itself.
  programs.home-manager.enable = lib.mkDefault true;

  # Declare icons symlink so KDE sees them
  xdg.dataFile."icons".source = "${SlotIcons}/share/icons";

  # ============================================================
  # USER PACKAGES
  # ============================================================
  # These are installed only for the operator user, not system-wide.
  # Offensive/OSINT/SDR tools have moved to modules/security-tools.nix
  # and are now system-wide packages.
  home.packages = with pkgs; [
    # ── Terminal & Shell ──────────────────────────────────────
    zsh # better shell than bash

    # ── Development ───────────────────────────────────────────
    gh # GitHub CLI
    github-desktop # Github GUI
    python3
    python3Packages.pip

    # ── Utilities ─────────────────────────────────────────────
    ripgrep # fast grep (rg)
    fd # fast find
    bat # cat with syntax highlighting
    fzf # fuzzy finder
    jq # JSON processor
    unzip
    p7zip
    file
    inetutils # Collection of common network programs
    wirelesstools # iwconfig
    net-tools
    dnsmasq
    lftp
    git
    wget
    curl
    htop
    tree
    act # Run github actions locally

    # ── Productivity ──────────────────────────────────────────
    obsidian # Note-taking and knowledge management*
    kdePackages.kleopatra # PGP Manager

    # ── STYLES ────────────────────────────────────────────────
    # ── Fonts ─────────────────────────────────────────────────
    kdePackages.fcitx5-qt # Fcitx5 Qt integration

    nerd-fonts.jetbrains-mono # terminal font with icons
    nerd-fonts.fira-code

    noto-fonts # Non-english char fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    # ── Icons ─────────────────────────────────────────────────
    SlotIcons
    # ── Cursors ───────────────────────────────────────────────
    nordzy-cursor-theme

    # ── Plasma widgets ────────────────────────────────────────
    TiledMenu
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

  # Copy TiledMenu into ~/.local/share/plasma/plasmoids/ — the canonical
  # user-level plasmoid path that Plasma scans at session start.
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

  # Directly patch the TiledMenu applet config in plasma-org.kde.plasma.desktop-appletsrc.
  # plasma-manager writes that file during writeBoundary; we read it here to find
  # the dynamic applet ID, then write the settings kwriteconfig6 style.
  # This is a belt-and-suspenders fallback in case plasma-manager's config.General
  # block doesn't fully propagate for third-party widgets.
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
    zsh = {
      enable = lib.mkDefault true;
      autosuggestion.enable = lib.mkDefault true; # suggests commands as you type
      syntaxHighlighting.enable = lib.mkDefault true; # colors valid/invalid commands
      enableCompletion = lib.mkDefault true;
      autocd = lib.mkDefault true; # Automaticaly enter into a directory if typed directly in the shell

      # Your shell aliases
      shellAliases = {
        ll = "ls -la";
        gs = "git status";
        gp = "git push";
        gl = "git pull";
        # rebuild — apply current config (same pinned versions, no input bump); kbuildsycoca6 runs via home.activation automatically
        # upgrade — update all flake inputs (nixpkgs, packages) then rebuild
        # update  — update inputs only, no rebuild (check what changed before committing)
        rebuild = "sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure && kbuildsycoca6";
        upgrade = "nix flake update --flake ~/.dotfiles && sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure && kbuildsycoca6";
        update = "nix flake update --flake ~/.dotfiles";

        # Networking
        ip_out = "curl -s https://ifconfig.me && echo";
        ip_local = "ip -4 addr show scope global | awk '/inet/{print $2}'";

        # Quick edit of your configs
        enix = "kate ~/.dotfiles/flake.nix";
        emod = "kate ~/.dotfiles/modules/";
        euser = "kate ~/.dotfiles/user/";
        ehome = "kate ~/.dotfiles/home.nix";

        # Tools
        ftp = "lftp";
        cat = "bat";
        seclists = ''
          sh -c "
            SECLISTS_PATH=\"\''${SECLISTS_PATH:-/run/current-system/sw/share/wordlists/seclists/}\" &&
            printf \"=== Seclists Explorer ===\n\n%s\n\nThis is the Seclists wordlists directory (read-only in Nix store). Listing top-level folders:\n\n\" \"\$SECLISTS_PATH\" &&
            ls -la --group-directories-first \"\$SECLISTS_PATH\" 2>/dev/null | awk '/^d/ {print}'
          "
        '';
      };

      initContent = ''
        # ── Key bindings ──────────────────────────────────────────────────────
        bindkey "^[[1;5C" forward-word         # Ctrl+Right — jump word forward
        bindkey "^[[1;5D" backward-word        # Ctrl+Left  — jump word back
        bindkey "^H"      backward-kill-word   # Ctrl+Bksp  — delete word back
        bindkey "^[[3;5~" kill-word            # Ctrl+Del   — delete word forward
        bindkey "^[[3~"   delete-char          # Delete     — delete char forward
        bindkey "^[[H"    beginning-of-line    # Home
        bindkey "^[[F"    end-of-line          # End

        # Up/Down: search history by the prefix already typed
        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        bindkey "^[[A" up-line-or-beginning-search    # Up
        bindkey "^[[B" down-line-or-beginning-search  # Down

        # ── AnNIXion banner ───────────────────────────────────────────────────
        echo ""
        echo "  \e[1;31m █████╗ ███╗   ██╗███╗  ██╗██╗██╗  ██╗██╗ ██████╗ ███╗ ██╗\e[0m"
        echo "  \e[1;31m██╔══██╗████╗  ██║████╗ ██║██║╚██╗██╔╝██║██╔═══██╗████╗██║\e[0m"
        echo "  \e[1;31m███████║██╔██╗ ██║██╔██╗██║██║ ╚███╔╝ ██║██║   ██║██╔████║\e[0m"
        echo "  \e[1;31m██╔══██║██║╚██╗██║██║╚████║██║ ██╔██╗ ██║██║   ██║██║╚███║\e[0m"
        echo "  \e[1;31m██║  ██║██║ ╚████║██║ ╚███║██║██╔╝╚██╗██║╚██████╔╝██║ ╚██║\e[0m"
        echo "  \e[1;31m╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚══╝╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝\e[0m"
        echo ""
        echo "  \e[0;90mhost\e[0m  $(hostname)"
        echo "  \e[0;90mdate\e[0m  $(date '+%A %d %B %Y  %H:%M')"
        echo "  \e[0;90mip  \e[0m  $(ip -4 addr show scope global 2>/dev/null | awk '/inet/{print $2}' | head -1)"
        echo ""
      '';
    };
    # ============================================================
    # GIT
    # ============================================================
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
