# Firmware analysis and extraction
{ bodies }:
{
  package = p: p.binwalk;
  name = "Binwalk";
  genericName = "Firmware Analyzer";
  comment = "Firmware analysis and extraction";
  exec = "binwalk";
  launch = "hold"; # konsole, shell kept open afterwards
  # Earns a place under a second phase as well.
  alsoIn = [ "re/firmware" ];
  mark = {
    class = "reverse";
    body = bodies.binwalk;
    over = bodies.binwalkOver;
  };
}
