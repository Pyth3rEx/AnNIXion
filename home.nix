# home.nix
# This file declares everything about YOUR user environment.
# Think of it as your personal layer on top of the system.
# Changes here only affect the "operator" user, not the whole system.
#
# Every option uses lib.mkDefault (priority 1000). That means anything
# you put in user/home.nix at normal priority (100) automatically wins
# without needing lib.mkForce.
{ config, lib, pkgs, ... }:

{
  # Home Manager needs to know your username and home directory.
  home.username = lib.mkDefault "operator";
  home.homeDirectory = lib.mkDefault "/home/operator";

  # Like system.stateVersion — do not change this ever.
  # It records the Home Manager version you first activated with.
  home.stateVersion = "25.11";

  # Let Home Manager manage itself.
  programs.home-manager.enable = lib.mkDefault true;

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

    # ── Fonts ─────────────────────────────────────────────────
    nerd-fonts.jetbrains-mono  # terminal font with icons
    nerd-fonts.fira-code
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
    userName = lib.mkDefault "CHANGME";
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
      lookAndFeel = "org.kde.breezedark.desktop";
      cursor = {
        theme = "Bibata-Modern-Ice";
        size = 32;
      };
      iconTheme = "Slot-Nord-Dark-Icons";
      wallpaper = "/home/operator/.dotfiles/assets/dementor-harry-5120x2880-18680.png"; # Wallpaper from https://4kwallpapers.com/black-dark/dementor-harry-18680.html - Will credit the artist once I find out who it is
      wallpaperFillMode = "preserveAspectFit";
      wallpaperBackground.color = "#000000";
    };

    kscreenlocker.appearance.wallpaper = "/home/operator/.dotfiles/assets/moon-planet-8k-7680x4320-87.jpg"; # Wallpaper from https://4kwallpapers.com/space/moon-planet-8k-87.html - Will credit the artist once I find out who it is

    fonts = {
      general = {
        family = "JetBrains Mono";
        pointSize = 12;
      };
    };

    panels = [
      # Windows-like panel at the bottom
      {
        location = "right";
        widgets = [
          # We can configure the widgets by adding the name and config
          # attributes. For example to add the the kickoff widget and set the
          # icon to "nix-snowflake-white" use the below configuration. This will
          # add the "icon" key to the "General" group for the widget in
          # ~/.config/plasma-org.kde.plasma.desktop-appletsrc.
          {
            name = "org.kde.plasma.kickoff";
            config = {
              General = {
                icon = "nix-snowflake-white";
                alphaSort = true;
              };
            };
          }
          # Adding configuration to the widgets can also for example be used to
          # pin apps to the task-manager, which this example illustrates by
          # pinning dolphin and konsole to the task-manager by default with widget-specific options.
          {
            iconTasks = {
              launchers = [
                "applications:org.kde.dolphin.desktop"
                "applications:org.kde.konsole.desktop"
              ];
            };
          }
          # If no configuration is needed, specifying only the name of the
          # widget will add them with the default configuration.
          "org.kde.plasma.marginsseparator"
          # If you need configuration for your widget, instead of specifying the
          # the keys and values directly using the config attribute as shown
          # above, plasma-manager also provides some higher-level interfaces for
          # configuring the widgets. See modules/widgets for supported widgets
          # and options for these widgets. The widgets below shows two examples
          # of usage, one where we add a digital clock, setting 12h time and
          # first day of the week to Sunday and another adding a systray with
          # some modifications in which entries to show.
          {
            digitalClock = {
              calendar.firstDayOfWeek = "monday";
              time.format = "24h";
            };
          }
          {
            systemTray.items = {
              # We explicitly show bluetooth and battery
              shown = [
                "org.kde.plasma.battery"
                "org.kde.plasma.bluetooth"
              ];
              # And explicitly hide networkmanagement and volume
              hidden = [
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.volume"
              ];
            };
          }
        ];
        hiding = "autohide";
      }
      # Application name, Global menu and Song information and playback controls at the top
      {
        location = "top";
        height = 26;
        widgets = [
          {
            applicationTitleBar = {
              behavior = {
                activeTaskSource = "activeTask";
              };
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
          "org.kde.plasma.panelspacer"
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
        ];
      }
    ];


    # ── Global shortcuts ──────────────────────────────────────
    shortcuts = lib.mkDefault {
      # KRunner — your app launcher (like wofi/rofi)
      "org.kde.krunner.desktop"."_launch" = [ "Alt+Space" "Alt+F2" ];

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

  # # ============================================================
  # # FONTS
  # # ============================================================
  # fonts.fontconfig.enable = lib.mkDefault true;
}