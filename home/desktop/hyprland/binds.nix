# Keybindings, carried over from home/desktop/plasma/shortcuts.nix where a
# Hyprland equivalent exists.
#
# annixion-raise (home/desktop/window-raise.nix), behind every Fn-key launcher
# in shortcuts.nix, shells out to wmctrl/xprop — X11-only, so it cannot carry
# over to a native Wayland session. Those per-app launch-or-focus hotkeys are
# dropped here rather than silently rebuilt into plain launches; the catalog's
# own .desktop entries (home/desktop/apps-menu.nix) already reach every tool
# through wofi (wofi.nix), unraised. Tracked as a follow-up once a
# Wayland-native replacement exists.
_:

{
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    "$term" = "konsole";

    bind = [
      # ── Workspaces (kwinrc.Desktops.Number = 4, kwin.nix) ────
      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod, 4, workspace, 4"

      "$mod CTRL, 1, movetoworkspace, 1"
      "$mod CTRL, 2, movetoworkspace, 2"
      "$mod CTRL, 3, movetoworkspace, 3"
      "$mod CTRL, 4, movetoworkspace, 4"

      # ── Focus movement — kwin.nix's Krohnkite binds the same chord ──
      "$mod SHIFT, up, movefocus, u"
      "$mod SHIFT, down, movefocus, d"
      "$mod SHIFT, left, movefocus, l"
      "$mod SHIFT, right, movefocus, r"

      # ── Window controls ───────────────────────────────────────
      "ALT, F4, killactive"
      "$mod, F, fullscreen, 0"
      "$mod, V, togglefloating"

      # ── Launchers ─────────────────────────────────────────────
      "$mod, Return, exec, $term"
      "$mod, Space, exec, wofi --show drun"
      "ALT, Space, exec, wofi --show drun"

      "$mod, L, exec, hyprlock"
    ];

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];
  };
}
