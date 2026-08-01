{
  config,
  lib,
  pkgs,
  ...
}:
# KDE Plasma desktop: plasma-manager config (panels, shortcuts, kwinrc/
# kdeglobals via configFile) plus the activation hooks that write kwinrc
# keys KWin resets at runtime and restart plasmashell after a rebuild.
{
  programs.plasma = {
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
              defaultAppListView = "JumpToCategory";
              sidebarShortcuts = "org.kde.konsole.desktop,org.kde.dolphin.desktop,systemsettings.desktop";
              showRecentApps = "false";
              icon = "${../assets/icons/AnNIXion.png}";
              fixedPanelIcon = "true";
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
  home.activation.restartPlasmashell =
    lib.hm.dag.entryAfter [ "installTiledMenu" "configureKwin" "configureTiledMenu" ]
      ''
        if [ -n "''${DISPLAY:-}" ]; then
          ${pkgs.kdePackages.plasma-workspace}/bin/plasmashell --replace \
            > /dev/null 2>&1 &
          disown 2>/dev/null || true
        fi
      '';
}
