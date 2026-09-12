# Global shortcuts, including the launch-or-focus hotkeys that reach for a
# window before starting a second copy of the application.
{
  lib,
  ...
}:
{
  programs.plasma = {

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
    # annixion-raise (home/desktop/window-raise.nix) focuses a live window
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

        # annixion-redteam sets MOZ_APP_REMOTINGNAME, which is what gives each
        # profile its own WM_CLASS, and starts Burp alongside the browser.
        firefox-red = raise "Meta+F4" "Firefox — Red Team" "firefox-red" "annixion-redteam";

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
  };
}
