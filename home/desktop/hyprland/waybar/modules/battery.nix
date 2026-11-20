{
  battery = {
    interval = 60;
    states = {
      warning = 30;
      critical = 15;
    };
    format = "{icon} <span size='11pt'>{capacity}%</span>";
    format-full = "{icon} <span size='11pt'>{capacity}%</span>";
    format-charging = "<span size='12pt'>󱐌</span> <span size='11pt'>{capacity}%</span>";
    format-plugged = " <span size='11pt'></span>";
    format-alt = "{icon} <span size='11pt'>{time}</span>";
    tooltip-format = "{timeTo}\n\n󰠠  Usage: {power:0.1f}W\n󱤅  Condition: {health}%\n󱍸  Total: {cycles} cycles";
    format-icons = {
      default = [
        "󰂎"
        "󰁺"
        "󰁻"
        "󰁼"
        "󰁽"
        "󰁾"
        "󰁿"
        "󰂀"
        "󰂁"
        "󰂂"
        "󰁹"
      ];
    };
  };
}
