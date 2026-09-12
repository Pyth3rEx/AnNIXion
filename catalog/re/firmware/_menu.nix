# Menu node: Firmware
{ bodies }:
{
  order = 2;
  menuName = "Firmware";
  label = "Firmware";
  directory = "annixion-9-re-firmware.directory";
  category = "X-AnNIXion-RE-Firmware";
  mark = {
    class = "reverse";
    body = bodies.binwalk;
    over = bodies.binwalkOver;
  };
}
