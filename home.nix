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

  # Tiled Menu — Windows-10-style start menu that reads the XDG applications
  # menu tree, so our kill-chain categories appear as the left-side column.
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
    $DRY_RUN_CMD rm -rf "$_tm"
    $DRY_RUN_CMD mkdir -p "$HOME/.local/share/plasma/plasmoids"
    $DRY_RUN_CMD cp -rL \
      "${TiledMenu}/share/plasma/plasmoids/com.github.zren.tiledmenu" \
      "$_tm"
  '';

  # Write kwinrc keys that KWin resets at runtime (plasma-manager configFile
  # is overwritten by KWin's own session-state writes each logout).
  # kwriteconfig6 writes directly to ~/.config/kwinrc before plasmashell
  # restarts, so KWin picks them up on the next load.
  home.activation.configureKwin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${DISPLAY:-}" ]; then
      # Bare Meta → activateLauncherMenu → TiledMenu
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group ModifierOnlyShortcuts --key Meta \
        "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu"
      # 4 virtual desktops
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Number 4
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Rows 1
    fi
  '';

  # Restart plasmashell after rebuild — depends on both widget install and
  # kwinrc being written so KWin loads with the correct config.
  home.activation.restartPlasmashell = lib.hm.dag.entryAfter [ "installTiledMenu" "configureKwin" ] ''
    if [ -n "''${DISPLAY:-}" ]; then
      ${pkgs.kdePackages.plasma-workspace}/bin/plasmashell --replace \
        > /dev/null 2>&1 &
      disown 2>/dev/null || true
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
    # ============================================================
    # KDE / KWIN SETTINGS (Krohnkite tiling + shortcuts)
    # ============================================================
    # These write directly into KDE's config files in ~/.config/
    # plasma-manager handles the translation to KDE format.
    plasma = {
      enable = lib.mkDefault true;
      # Force plasma-manager to overwrite KDE config files on every rebuild.
      # Without this, KDE's own writes to kwinrc/kdeglobals etc. survive the
      # rebuild on old installs and the declared state is silently ignored.
      overrideConfig = lib.mkDefault true;

      # ── Global astetics ──────────────────────────────────────
      workspace = lib.mkDefault {
        clickItemTo = "open"; # If you liked the click-to-open default from plasma 5
        lookAndFeel = "org.kde.breezedark.desktop";
        cursor = {
          theme = "Nordzy-cursors";
          size = 32;
        };
        iconTheme = "Slot-Nord-Dark-Colorize-Icons";
        wallpaper = "${config.home.homeDirectory}/.dotfiles/assets/wallpaper/wallpaper_1.png";
        wallpaperFillMode = "preserveAspectFit";
        wallpaperBackground.color = "#000000";
      };

      kscreenlocker.appearance.wallpaper = "${config.home.homeDirectory}/.dotfiles/assets/wallpaper/wallpaper_2.png";

      fonts = {
        general = {
          family = "JetBrains Mono";
          pointSize = 12;
        };
      };

      panels = [

        # ── Single top panel ──────────────────────────────────────────────────
        # Layout (left → right):
        #   [vol] [net] [BT] ┃ [window title] [app menu] [tasks] ── [music] [clock] [tray] [kickoff]
        {
          location = "top";
          screen = 0;
          height = 32;
          opacity = "adaptive";
          widgets = [

            # ── Control center (left) ──────────────────────────────────────
            "org.kde.plasma.volume"
            "org.kde.plasma.networkmanagement"
            "org.kde.plasma.bluetooth"
            "org.kde.plasma.marginsseparator"

            # ── Window info & app menu ────────────────────────────────────
            {
              applicationTitleBar = {
                behavior.activeTaskSource = "activeTask";
                layout = {
                  elements = [ "windowTitle" ];
                  horizontalAlignment = "left";
                  showDisabledElements = "deactivated";
                  verticalAlignment = "center";
                };
                overrideForMaximized.enable = false;
                titleReplacements = [
                  {
                    type = "regexp";
                    originalTitle = "^Brave Web Browser$";
                    newTitle = "Brave";
                  }
                  {
                    type = "regexp";
                    originalTitle = ''\\bDolphin\\b'';
                    newTitle = "File manager";
                  }
                ];
                windowTitle = {
                  font = {
                    bold = false;
                    fit = "fixedSize";
                    size = 12;
                  };
                  hideEmptyTitle = true;
                  margins = {
                    bottom = 0;
                    left = 10;
                    right = 5;
                    top = 0;
                  };
                  source = "appName";
                };
              };
            }
            "org.kde.plasma.appmenu"

            # ── Task manager ──────────────────────────────────────────────
            {
              iconTasks = {
                launchers = [
                  "applications:org.kde.dolphin.desktop"
                  "applications:org.kde.konsole.desktop"
                ];
              };
            }

            # ── Flexible space ────────────────────────────────────────────
            "org.kde.plasma.panelspacer"

            # ── Music / status / clock / tray ─────────────────────────────
            {
              plasmusicToolbar = {
                panelIcon = {
                  albumCover = {
                    useAsIcon = false;
                    radius = 8;
                  };
                  icon = "view-media-track";
                };
                playbackSource = "auto";
                musicControls.showPlaybackControls = true;
                songText = {
                  displayInSeparateLines = true;
                  maximumWidth = 640;
                  scrolling = {
                    behavior = "alwaysScroll";
                    speed = 3;
                  };
                };
              };
            }
            {
              digitalClock = {
                calendar.firstDayOfWeek = "monday";
                time.format = "24h";
              };
            }
            {
              systemTray.items = {
                shown = [ "org.kde.plasma.battery" ];
                hidden = [
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.bluetooth"
                  "org.kde.plasma.volume"
                ];
              };
            }

            # ── Tiled Menu — far right edge ───────────────────────────────
            # Installed via home.activation.installTiledMenu (cp into
            # ~/.local/share/plasma/plasmoids/).
            {
              name = "com.github.zren.tiledmenu";
              config.General = {
                # Show the kill-chain category tree (left column) instead of
                # the default flat alphabetical list.
                defaultAppListView = "Categories";
                # Sidebar icons: terminal, files, settings
                sidebarShortcuts = "org.kde.konsole.desktop,org.kde.dolphin.desktop,systemsettings.desktop";
                showRecentApps = "false";
              };
            }

          ];
        }

      ];

      # ── Global shortcuts ──────────────────────────────────────
      shortcuts = lib.mkDefault {
        # KRunner — your app launcher (like wofi/rofi)
        "org.kde.krunner.desktop"."_launch" = [
          "Alt+Space"
          "Alt+F2"
        ];

        # Tiled Menu — Meta+F1 via kglobalaccel (bare Meta handled by
        # ModifierOnlyShortcuts in configFile below; both are needed)
        "com.github.zren.tiledmenu.desktop"."_launch" = [ "Meta+F1" ];

        # KWin window management
        kwin = {
          # Virtual desktops — switch with Meta+number
          "Switch to Desktop 1" = "Meta+1";
          "Switch to Desktop 2" = "Meta+2";
          "Switch to Desktop 3" = "Meta+3";
          "Switch to Desktop 4" = "Meta+4";

          # Move window to desktop
          "Window to Desktop 1" = "Meta+Shift+1";
          "Window to Desktop 2" = "Meta+Shift+2";
          "Window to Desktop 3" = "Meta+Shift+3";
          "Window to Desktop 4" = "Meta+Shift+4";

          # Window controls
          "Window Maximize" = "Meta+Up";
          "Window Minimize" = "Meta+Down";
          "Window Close" = "Meta+Q";
          "Window Fullscreen" = "Meta+F";

          # Focus switching (Krohnkite uses these)
          "Switch Window Up" = "Meta+Shift+Up";
          "Switch Window Down" = "Meta+Shift+Down";
          "Switch Window Left" = "Meta+Shift+Left";
          "Switch Window Right" = "Meta+Shift+Right";
        };

        # Launch terminal with Meta+Return
        "org.kde.kglobalaccel.desktop"."run command" = "Meta+Return";
      };

      # ── KWin config (Krohnkite tiling script) ─────────────────
      configFile = lib.mkDefault {
        # Enable Krohnkite tiling script
        "kwinrc"."Plugins"."krohnkiteEnabled" = true;

        # Virtual desktops — 4 desktops like a proper tiling setup
        "kwinrc"."Desktops"."Number" = 4;
        "kwinrc"."Desktops"."Rows" = 1;

        # Window behavior
        "kwinrc"."Windows"."FocusPolicy" = "FocusFollowsMouse";
        "kwinrc"."Windows"."FocusStealingPreventionLevel" = 1;

        # Compositor — keep effects minimal for VM performance
        "kwinrc"."Compositing"."AnimationSpeed" = 3;
        "kwinrc"."Compositing"."Enabled" = true;

        # Dark theme
        "kdeglobals"."General"."ColorScheme" = "BreezeDark";
        "kdeglobals"."KDE"."LookAndFeelPackage" = "org.kde.breezedark.desktop";

        # Bare Meta → activateLauncherMenu → TiledMenu toggles open/closed.
        # TiledMenu registers as an Application Launcher applet, so plasmashell
        # targets it when this D-Bus method is called.
        "kwinrc"."ModifierOnlyShortcuts"."Meta" =
          "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu";

        # Krohnkite tiling settings
        "kwinrc"."Script-krohnkite"."enableTileLayout" = true;
        "kwinrc"."Script-krohnkite"."screenGapTop" = 8;
        "kwinrc"."Script-krohnkite"."screenGapBottom" = 8;
        "kwinrc"."Script-krohnkite"."screenGapLeft" = 8;
        "kwinrc"."Script-krohnkite"."screenGapRight" = 8;
        "kwinrc"."Script-krohnkite"."tileLayoutGap" = 8;
        "kwinrc"."Script-krohnkite"."masterRatio" = "0.55";
      };
    };
  };
}
