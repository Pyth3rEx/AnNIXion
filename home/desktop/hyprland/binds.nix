# Carried over from plasma/shortcuts.nix where a Hyprland equivalent exists. annixion-raise's per-app launch-or-focus hotkeys are dropped (it shells out to X11-only wmctrl/xprop) rather than rebuilt as plain launches — wofi already reaches every tool, unraised. Follow-up once a Wayland-native replacement exists.
_:

{
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    "$term" = "konsole";

    bind = [
      # Workspaces (kwinrc.Desktops.Number = 4, kwin.nix)
      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod, 4, workspace, 4"

      "$mod CTRL, 1, movetoworkspace, 1"
      "$mod CTRL, 2, movetoworkspace, 2"
      "$mod CTRL, 3, movetoworkspace, 3"
      "$mod CTRL, 4, movetoworkspace, 4"

      # Focus movement — kwin.nix's Krohnkite binds the same chord
      "$mod SHIFT, up, movefocus, u"
      "$mod SHIFT, down, movefocus, d"
      "$mod SHIFT, left, movefocus, l"
      "$mod SHIFT, right, movefocus, r"

      # Window controls
      "ALT, F4, killactive"
      "$mod, F, fullscreen, 0"
      "$mod, V, togglefloating"

      # Launchers
      "$mod, Return, exec, $term"
      "$mod, Q, exec, $term"
      "$mod, Space, exec, wofi --show drun"
      "ALT, Space, exec, wofi --show drun"

      "$mod, L, exec, hyprlock"

      # Ends the compositor back to SDDM — switching to Plasma is a logout, not a reboot.
      "$mod SHIFT, E, exit"
    ];

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];

    # Bare SUPER opens wofi, the Wayland stand-in for Plasma's Tiled Menu; bindr fires on release so it doesn't fight the $mod chords above, which fire on press.
    bindr = [
      "$mod, SUPER_L, exec, wofi --show drun"
    ];
  };
}
