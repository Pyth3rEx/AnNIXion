{
  "custom/tray-arrow" = {
    format = "{icon}";
    tooltip = false;
    format-icons = {
      notification = "󱅫";
      none = "󰏖";
      dnd-notification = "󰂠";
      dnd-none = "󰪓";
      inhibited-notification = "󰂛";
      inhibited-none = "󰪑";
      dnd-inhibited-notification = "󰂛";
      dnd-inhibited-none = "󰪑";
    };
    return-type = "json";
    exec-if = "which swaync-client";
    exec = "swaync-client -swb";
    on-click = "swaync-client -t -sw";
    on-click-right = "swaync-client -d -sw";
    escape = true;
  };
  tray = {
    icon-size = 16;
    spacing = 10;
    show-passive-items = true;
  };
}
