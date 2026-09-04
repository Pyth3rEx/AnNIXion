# Network protocol capture and analysis
{ bodies }:
{
  package = p: p.wireshark;
  name = "Wireshark";
  genericName = "Packet Analyzer";
  comment = "Network protocol capture and analysis";
  exec = "wireshark";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "org.wireshark.Wireshark" ];
  mark = {
    class = "forensic";
    body = bodies.wireshark;
  };
}
