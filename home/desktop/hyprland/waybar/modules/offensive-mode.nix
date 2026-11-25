{
  "custom/offensive-mode" = {
    exec = ''
      if systemctl is-active --quiet annixion-offensive.service; then
        printf '{"text":"󰐼","class":"activated","tooltip":"Offensive networking: armed"}'
      else
        printf '{"text":"󰻁","class":"deactivated","tooltip":"Offensive networking: safe"}'
      fi
    '';
    return-type = "json";
    interval = 30;
    signal = 8;
    on-click = ''
      systemctl is-active --quiet annixion-offensive.service \
        && systemctl stop annixion-offensive.service \
        || systemctl start annixion-offensive.service
      pkill -RTMIN+8 waybar
    '';
  };
}
