{
  "hyprland/workspaces" = {
    format = "{icon} {windows}";
    on-click = "activate";
    move-to-monitor = true; # Monitor to window or window to monitor
    persistent-workspaces = {
      "*" = 5;
    };
    window-rewrite-default = "󰊠";
    window-rewrite = {
      kitty = "󰆍";
      konsole = "󰆍";
      onlyoffice = "󰏆";
      firefox = "󰈹";
      code = "󰨞";
      codium = "󰨞";
      azahar = "󰮂";
      obsidian = "󰹕";
      mousepad = "󱓧";
      discord = "󰙯";
      spotify = "󰓇";
      "org.kde.kdeconnect.app" = "󰦉";
      "org.qbittorrent.qBittorrent" = "󰘿";
      xdg-desktop-portal-gtk = "󱒃";
      thunar = "󰉋";
      yazi = "󰇥";
      imv = "󰄄";
      swappy = "󰄄";
      "org.gnome.FileRoller" = "󰛫";
      vlc = "󰕼";
      mpv = "󰕼";
      blueman-manager = "󰂳";
      pavucontrol = "󱕂";
      nm-connection-editor = "󰐻";
      nwg-look = "󰒓";
      qt5ct = "󰒓";
      qt6ct = "󰒓";
      designer = "󰒓";
      linguist = "󰒓";
      assistant = "󰒓";
      pixeltool = "󰒓";
      qdbusviewer = "󰒓";
    };
    format-icons = {
      # Pac-Man (active), ghost (shown on another monitor but not focused),
      # pac-dot (not displayed on any monitor)
      active = "󰮯";
      visible = "󰊠";
      default = "󰧟";
      empty = "󰧟";
      special = "󱁂";
      urgent = "󰧵";
    };
    show-special = true;
    all-outputs = true;
  };
}
