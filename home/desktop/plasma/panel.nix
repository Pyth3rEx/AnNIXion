# The single top panel and every widget on it, left to right.
# Ordering in this list is the ordering on screen.
{
  lib,
  ...
}:
let
  tileModel = import ./start-menu.nix { inherit lib; };
in
{
  programs.plasma = {

    panels = [

      # ── Single top panel ──────────────────────────────────────────────────
      # Layout (left → right), described in docs/customization.md:
      #   [desktops] | [tasks] ── [menu] [app name] ── [cam] [net] [BT] [vol] [bat] [tray] [clock] [◆]
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

          # Divides the desktop pager from the launchers, which otherwise read
          # as one run of squares. home/desktop/panel-separator.nix.
          "com.annixion.separator"

          {
            iconTasks = {
              # The everyday five, not the whole hotkey set: a pinned icon is
              # worth its width only for what is opened without thinking, and
              # the rest stay a Meta+F<N> or a menu entry away. Order still
              # follows hotkeys.commands, so these are F1, F2, F4, F5 and F6.
              #
              # Where a stock entry and an annixion-* one both exist the stock
              # one is pinned: Plasma matches a window to a launcher by class,
              # and only the stock name resolves. Their marks reach them through
              # the alias set in home/desktop/icons/default.nix, since a stock entry asks
              # for a stock icon name. The rest have no stock equivalent and
              # carry their own StartupWMClass.
              launchers = [
                # Terminals
                "applications:org.kde.konsole.desktop"
                "applications:annixion-konsole-root.desktop"
                # Browser profiles. Red Team also brings up Burp — see
                # home/desktop/redteam-launch.nix.
                "applications:firefox-red.desktop"
                "applications:firefox-osint.desktop"
                "applications:firefox-puppet.desktop"
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
  };
}
