# home.nix
# This file declares everything about YOUR user environment.
# Think of it as your personal layer on top of the system.
# Changes here only affect the "operator" user, not the whole system.
#
# Every option uses lib.mkDefault (priority 1000). That means anything
# you put in user/home.nix at normal priority (100) automatically wins
# without needing lib.mkForce.
{ inputs, config, lib, pkgs, ... }:

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
in {
  imports = [
    ./home/firefox
    ./home/apps-menu.nix
    ./home/control-center.nix
  ];

  # Home Manager needs to know your username and home directory.
  home.username = lib.mkDefault "operator";
  home.homeDirectory = lib.mkDefault "/home/operator";

  # Like system.stateVersion — do not change this ever.
  # It records the Home Manager version you first activated with.
  home.stateVersion = "25.11";

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
    zsh            # better shell than bash

    # ── Development ───────────────────────────────────────────
    vscode
    gh             # GitHub CLI
    github-desktop # Github GUI
    python3
    python3Packages.pip

    # ── Utilities ─────────────────────────────────────────────
    ripgrep        # fast grep (rg)
    fd             # fast find
    bat            # cat with syntax highlighting
    fzf            # fuzzy finder
    jq             # JSON processor
    unzip
    p7zip

    # ── STYLES ────────────────────────────────────────────────
    # ── Fonts ─────────────────────────────────────────────────
    nerd-fonts.jetbrains-mono  # terminal font with icons
    nerd-fonts.fira-code
    # ── Icons ─────────────────────────────────────────────────
    SlotIcons
    # ── Cursors ───────────────────────────────────────────────
    nordzy-cursor-theme
  ];
  
  programs.zsh = {
    enable = lib.mkDefault true;
    autosuggestion.enable = lib.mkDefault true;      # suggests commands as you type
    syntaxHighlighting.enable = lib.mkDefault true;  # colors valid/invalid commands
    enableCompletion = lib.mkDefault true;
    autocd = lib.mkDefault true;                     # Automaticaly enter into a directory if typed directly in the shell

    # Your shell aliases
    shellAliases = {
      ll = "ls -la";
      gs = "git status";
      gp = "git push";
      gl = "git pull";
      rebuild = "sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure";

      # Networking
      myip      = "curl -s https://ifconfig.me && echo";
      localip   = "ip -4 addr show scope global | awk '/inet/{print $2}'";
      
      # Quick edit of your configs
      enix  = "kate ~/.dotfiles/flake.nix";
      emod  = "kate ~/.dotfiles/modules/";
      euser = "kate ~/.dotfiles/user/";
      ehome = "kate ~/.dotfiles/home.nix";
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
  programs.git.settings = {
    enable = lib.mkDefault true;
    userName = lib.mkDefault "CHANGEME";
    userEmail = lib.mkDefault "your@email.com";
    extraConfig = lib.mkDefault {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # ============================================================
  # KDE / KWIN SETTINGS (Krohnkite tiling + shortcuts)
  # ============================================================
  # These write directly into KDE's config files in ~/.config/
  # plasma-manager handles the translation to KDE format.

  programs.plasma = {
    enable = lib.mkDefault true;

    # ── Global astetics ──────────────────────────────────────
    workspace = lib.mkDefault {
      clickItemTo = "open"; # If you liked the click-to-open default from plasma 5
      # lookAndFeel = "org.kde.breezedark.desktop";
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
                elements              = [ "windowTitle" ];
                horizontalAlignment   = "left";
                showDisabledElements  = "deactivated";
                verticalAlignment     = "center";
              };
              overrideForMaximized.enable = false;
              titleReplacements = [
                {
                  type          = "regexp";
                  originalTitle = "^Brave Web Browser$";
                  newTitle      = "Brave";
                }
                {
                  type          = "regexp";
                  originalTitle = ''\\bDolphin\\b'';
                  newTitle      = "File manager";
                }
              ];
              windowTitle = {
                font = { bold = false; fit = "fixedSize"; size = 12; };
                hideEmptyTitle = true;
                margins = { bottom = 0; left = 10; right = 5; top = 0; };
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
                albumCover = { useAsIcon = false; radius = 8; };
                icon = "view-media-track";
              };
              playbackSource = "auto";
              musicControls.showPlaybackControls = true;
              songText = {
                displayInSeparateLines = true;
                maximumWidth = 640;
                scrolling = { behavior = "alwaysScroll"; speed = 3; };
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
              shown  = [ "org.kde.plasma.battery" ];
              hidden = [
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.volume"
              ];
            };
          }

          # ── Kickoff — far right edge ───────────────────────────────────
          {
            name = "org.kde.plasma.kickoff";
            config.General = {
              icon           = "${config.home.homeDirectory}/.dotfiles/assets/icons/AnNIXion.png";
              showRecentApps = false;
              showRecentDocs = false;
            };
          }

        ];
      }

    ];


    # ── Global shortcuts ──────────────────────────────────────
    shortcuts = lib.mkDefault {
      # KRunner — your app launcher (like wofi/rofi)
      "org.kde.krunner.desktop"."_launch" = [ "Alt+Space" "Alt+F2" ];

      # Kickoff — Meta+F1 via kglobalaccel (bare Meta handled by
      # ModifierOnlyShortcuts in configFile below; both are needed)
      "org.kde.plasma.kickoff.desktop"."_launch" = [ "Meta+F1" ];

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

      # Meta key dispatch — handled by the annixion-meta-key systemd service
      # (see home/control-center.nix). Single press → control center,
      # double press (< 400 ms) → kickoff.
      "kwinrc"."ModifierOnlyShortcuts"."Meta" = "org.annixion.MetaKey,/MetaKey,org.annixion.MetaKey,Press";

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
}