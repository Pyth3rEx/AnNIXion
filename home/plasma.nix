{
  config,
  lib,
  pkgs,
  ...
}:
# KDE Plasma desktop: panels, shortcuts and kwinrc/kdeglobals via
# plasma-manager, plus the activation hooks that re-apply what KWin resets.
{
  programs.plasma = {
    enable = lib.mkDefault true;
    # Without this, KDE's own writes survive the rebuild and the declared
    # state is silently ignored.
    overrideConfig = lib.mkDefault true;

    # ── Global aesthetics ────────────────────────────────────
    workspace = lib.mkDefault {
      clickItemTo = "open";
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
          # Installed by home.activation.installTiledMenu.
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
      # KRunner
      "org.kde.krunner.desktop"."_launch" = [
        "Alt+Space"
        "Alt+F2"
      ];

      # Tiled Menu — bare Meta is handled by ModifierOnlyShortcuts
      # in configFile below; both bindings are needed.
      "com.github.zren.tiledmenu.desktop"."_launch" = [ "Meta+F1" ];

      # ── KWin ────────────────────────────────────────────────
      kwin = {
        # Virtual desktops
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

        # Focus switching — Krohnkite uses these
        "Switch Window Up" = "Meta+Shift+Up";
        "Switch Window Down" = "Meta+Shift+Down";
        "Switch Window Left" = "Meta+Shift+Left";
        "Switch Window Right" = "Meta+Shift+Right";
      };

      # Terminal
      "org.kde.kglobalaccel.desktop"."run command" = "Meta+Return";
    };

    # ── KWin config (Krohnkite tiling script) ─────────────────
    # No lib.mkDefault: configFile is opaque attrs that plasma-manager
    # also writes at normal priority, so mkDefault loses the whole block
    # instead of merging.
    configFile = {
      "kwinrc"."Plugins"."krohnkiteEnabled" = true;

      # Virtual desktops
      "kwinrc"."Desktops"."Number" = 4;
      "kwinrc"."Desktops"."Rows" = 1;

      # Window behaviour
      "kwinrc"."Windows"."FocusPolicy" = "FocusFollowsMouse";
      "kwinrc"."Windows"."FocusStealingPreventionLevel" = 1;

      # Compositor — minimal effects for VM performance
      "kwinrc"."Compositing"."AnimationSpeed" = 3;
      "kwinrc"."Compositing"."Enabled" = true;

      # Indexing file contents means parsing them.
      "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;

      # Dolphin's own view is set in home/file-visibility.nix.
      "kdeglobals"."KFileDialog Settings"."Show Hidden Files" = true;

      # TiledMenu registers as an Application Launcher applet, so this
      # D-Bus method toggles it.
      "kwinrc"."ModifierOnlyShortcuts"."Meta" =
        "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu";

      # ── Krohnkite ───────────────────────────────────────────
      "kwinrc"."Script-krohnkite"."enableTileLayout" = true;
      "kwinrc"."Script-krohnkite"."screenGapTop" = 8;
      "kwinrc"."Script-krohnkite"."screenGapBottom" = 8;
      "kwinrc"."Script-krohnkite"."screenGapLeft" = 8;
      "kwinrc"."Script-krohnkite"."screenGapRight" = 8;
      "kwinrc"."Script-krohnkite"."tileLayoutGap" = 8;
      "kwinrc"."Script-krohnkite"."masterRatio" = "0.55";
    };
  };

  # KWin's session-state writes overwrite configFile on every logout, so
  # re-apply those keys before plasmashell restarts.
  home.activation.configureKwin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${DISPLAY:-}" ]; then
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group ModifierOnlyShortcuts --key Meta \
        "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu"
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Number 4
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kwinrc --group Desktops --key Rows 1
    fi
  '';

  # Ordered after the widget install and the kwinrc writes.
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
