{
  network = {
    format-wifi = "{icon}";
    format-ethernet = "󰌗";
    format-linked = "󱘖";
    format-disconnected = "󰤣";
    format-disabled = "󰤮";
    format-icons = [
      "󰤯"
      "󰤟"
      "󰤢"
      "󰤥"
      "󰤨"
    ];
    tooltip-format-disconnected = "No Connection";
    tooltip-format-disabled = "Wi-Fi is OFF";
    tooltip-format-wifi = "󱄙  {essid} ({signalStrength}%)\n\n󰐻  Freq: {frequency}GHz\n  {bandwidthDownBytes}   {bandwidthUpBytes}";
    tooltip-format-ethernet = "󰈀  {ifname} (Connected)\n  {bandwidthDownBytes}   {bandwidthUpBytes}";
    tooltip-format-linked = "󱘖 {ifname}: No IP Address";
    on-click = "nm-applet --indicator";
    on-click-right = "pkill nm-applet";
    on-scroll-up = "nmcli radio wifi on";
    on-scroll-down = "nmcli radio wifi off";
  };
  bluetooth = {
    format = "󰂯";
    format-connected = "󰂱";
    format-disabled = "󰂲";
    tooltip-format = "{controller_alias} {status}";
    tooltip-format-connected = "󰐻  {num_connections} Connected:\n{device_enumerate}";
    tooltip-format-enumerate-connected-battery = "󰂱  {device_alias} (󰠠  {device_battery_percentage}%)";
    on-click = "blueman-manager";
    on-click-right = "rfkill toggle bluetooth";
  };
}
