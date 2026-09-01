{
  config,
  lib,
  pkgs,
  ...
}:
# KDE Plasma desktop: panels, shortcuts and kwinrc/kdeglobals via
# plasma-manager, plus the activation hooks that re-apply what KWin resets.
let
  tileModel = import ./start-menu.nix { inherit lib; };
in
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
      # AnNIXion carries the menu marks and inherits Slot-Dark-Icons for
      # everything else. The Colorize theme it replaced shipped places only,
      # so every application icon fell through to stock breeze-dark.
      iconTheme = "AnNIXion";
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
      # Layout (left → right), described in docs/customization.md:
      #   [desktops] [tasks] ── [menu] [app name] ── [cam] [net] [BT] [vol] [bat] [tray] [clock] [◆]
      {
        location = "top";
        screen = 0;
        height = 32;
        opacity = "adaptive";
        widgets = [

          # ── Workspace (left) ──────────────────────────────────────────
          {
            pager = {
              general = {
                displayedText = "desktopNumber";
                navigationWrapsAround = true;
              };
            };
          }
          {
            iconTasks = {
              # Same set as hotkeys.commands, in Meta+F<N> order, so the
              # Nth icon is the Nth key. Where a stock entry and an
              # annixion-* one both exist the stock one is pinned: Plasma
              # matches a window to a launcher by class, and only the stock
              # name resolves. Their marks reach them through the alias set in
              # home/icons/default.nix, since a stock entry asks for a stock
              # icon name. The rest have no stock equivalent and carry their
              # own StartupWMClass.
              launchers = [
                # Heavy use
                "applications:org.kde.konsole.desktop"
                "applications:annixion-konsole-root.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:firefox-red.desktop"
                # Offensive
                "applications:firefox-osint.desktop"
                "applications:firefox-puppet.desktop"
                "applications:burpsuite.desktop"
                "applications:annixion-metasploit.desktop"
                "applications:org.wireshark.Wireshark.desktop"
                "applications:ghidra.desktop"
                # Work
                "applications:annixion-vscodium.desktop"
                "applications:obsidian.desktop"
              ];
            };
          }

          # ── Centring ──────────────────────────────────────────────────
          # Plasma sizes a pair of expanding spacers so whatever sits
          # between them lands on the panel centre. Nothing else here.
          { panelSpacer.expanding = true; }

          # ── Focused app (centre) ──────────────────────────────────────
          { appMenu.compactView = true; }
          {
            applicationTitleBar = {
              behavior = {
                activeTaskSource = "activeTask";
                # The applet filters by screen by default, so the bar would
                # go blank for a window focused on another display.
                filterByScreen = false;
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
                # Fixed width keeps the group still as titles change.
                minimumWidth = 220;
                maximumWidth = 220;
                horizontalAlignment = "center";
                source = "appName";
              };
            };
          }

          { panelSpacer.expanding = true; }

          # ── System categories (right) ─────────────────────────────────
          # Each applet owns a category and shows its state in the icon.
          "org.kde.plasma.cameraindicator"
          "org.kde.plasma.networkmanagement"
          "org.kde.plasma.bluetooth"
          "org.kde.plasma.volume"
          "org.kde.plasma.battery"

          # ── System & status ───────────────────────────────────────────
          # hidden must repeat the standalone applets above, or the tray
          # renders a second copy of each.
          {
            systemTray.items = {
              shown = [ "org.kde.plasma.notifications" ];
              hidden = [
                "org.kde.plasma.cameraindicator"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.volume"
                "org.kde.plasma.battery"
                "org.kde.plasma.clipboard"
                "org.kde.plasma.devicenotifier"
                "org.kde.plasma.kscreen"
                "org.kde.plasma.mediacontroller"
              ];
            };
          }
          {
            digitalClock = {
              calendar.firstDayOfWeek = "monday";
              time.format = "24h";
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
              # The vector mark, not the datamosh PNG: the panel draws this
              # at 32px, where the glitch bars collapse into a smear.
              icon = "annixion-logo";
              fixedPanelIcon = "true";
              # Written here rather than by an activation hook: plasma-manager
              # deletes the appletsrc before replaying its layout script, so a
              # hook that edits that file loses whatever it wrote.
              inherit tileModel;
            };
          }

        ];
      }

    ];

    # ── Global shortcuts ──────────────────────────────────────
    # mkDefault per binding, not on the block: plasma-manager's own
    # krunner/spectacle modules write into this attrset at normal
    # priority, and a block-level mkDefault loses all of it to them.
    shortcuts = lib.mapAttrs (_: lib.mapAttrs (_: lib.mkDefault)) {
      # KRunner
      "org.kde.krunner.desktop"."_launch" = [
        "Alt+Space"
        "Alt+F2"
      ];

      # Tiled Menu opens on bare Meta, via ModifierOnlyShortcuts in
      # configFile below. It has no .desktop entry of its own — it is a
      # plasmoid — so kglobalaccel cannot bind it a key here.

      # ── KWin ────────────────────────────────────────────────
      kwin = {
        # Virtual desktops
        "Switch to Desktop 1" = "Meta+1";
        "Switch to Desktop 2" = "Meta+2";
        "Switch to Desktop 3" = "Meta+3";
        "Switch to Desktop 4" = "Meta+4";

        # Move window to desktop — Meta+Shift+N belongs to the launchers
        "Window to Desktop 1" = "Meta+Ctrl+1";
        "Window to Desktop 2" = "Meta+Ctrl+2";
        "Window to Desktop 3" = "Meta+Ctrl+3";
        "Window to Desktop 4" = "Meta+Ctrl+4";

        # Window controls
        "Window Maximize" = "Meta+Up";
        "Window Minimize" = "Meta+Down";
        # Alt+F4, not a Meta chord: Q sits under 1 and 2, so a slip off a
        # desktop switch closed the window. Closing is the one control here
        # worth breaking the Meta pattern for.
        "Window Close" = "Alt+F4";
        "Window Fullscreen" = "Meta+F";

        # Focus switching — Krohnkite uses these
        "Switch Window Up" = "Meta+Shift+Up";
        "Switch Window Down" = "Meta+Shift+Down";
        "Switch Window Left" = "Meta+Shift+Left";
        "Switch Window Right" = "Meta+Shift+Right";

        # KWin ships these on Meta+F5 and Meta+F6, which the launchers
        # below now claim. An empty list writes "none".
        "MoveMouseToFocus" = [ ];
        "MoveMouseToCenter" = [ ];
      };

      # Terminal
      "org.kde.kglobalaccel.desktop"."run command" = "Meta+Return";
    };

    # ── Launch-or-focus hotkeys ───────────────────────────────
    # annixion-raise (home/window-raise.nix) focuses a live window
    # before it starts a second copy; the glob matches WM_CLASS.
    hotkeys.commands =
      let
        raise = key: name: pattern: command: {
          inherit key name;
          comment = name;
          # The glob is quoted: desktop Exec rejects a bare '*'.
          command = ''annixion-raise "${pattern}" ${command}'';
        };
      in
      lib.mkDefault {
        # ── Heavy use ───────────────────────────────────────────
        konsole = raise "Meta+F1" "Konsole" "konsole.konsole" "konsole";

        konsole-root =
          raise "Meta+F2" "Konsole (root)" "konsole-root"
            "konsole -name konsole-root --profile Root -e sudo -i";

        dolphin = raise "Meta+F3" "Dolphin" "dolphin" "dolphin";

        # MOZ_APP_REMOTINGNAME is what gives each profile its own WM_CLASS.
        firefox-red =
          raise "Meta+F4" "Firefox — Red Team" "firefox-red"
            ''env MOZ_APP_REMOTINGNAME=firefox-red firefox -P "Red Team" --no-remote'';

        # ── Offensive ───────────────────────────────────────────
        firefox-osint =
          raise "Meta+F5" "Firefox — OSINT" "firefox-osint"
            ''env MOZ_APP_REMOTINGNAME=firefox-osint annixion-vpn-browser "OSINT"'';

        firefox-puppet =
          raise "Meta+F6" "Firefox — Puppet Master" "firefox-puppet"
            ''env MOZ_APP_REMOTINGNAME=firefox-puppet annixion-vpn-browser "Puppet Master"'';

        burpsuite = raise "Meta+F7" "Burp Suite" "burp*" "burpsuite";

        metasploit = raise "Meta+F8" "Metasploit" "konsole-msf" "konsole -name konsole-msf -e msfconsole";

        wireshark = raise "Meta+F9" "Wireshark" "wireshark" "wireshark";

        # Java sets both halves of WM_CLASS to the StartupWMClass name.
        ghidra = raise "Meta+F10" "Ghidra" "ghidra*" "ghidra";

        # ── Work ────────────────────────────────────────────────
        vscodium = raise "Meta+F11" "VSCodium" "vscodium" "codium";

        obsidian = raise "Meta+F12" "Obsidian" "obsidian" "obsidian";
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
  home.activation.restartPlasmashell = lib.hm.dag.entryAfter [ "installTiledMenu" "configureKwin" ] ''
    if [ -n "''${DISPLAY:-}" ]; then
      ${pkgs.kdePackages.plasma-workspace}/bin/plasmashell --replace \
        > /dev/null 2>&1 &
      disown 2>/dev/null || true
    fi
  '';
}
