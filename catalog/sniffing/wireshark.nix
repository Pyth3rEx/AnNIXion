# Network protocol capture and analysis
{ bodies }:
{
  package = p: p.wireshark;
  name = "Wireshark";
  genericName = "Packet Analyzer";
  comment = "Network protocol capture and analysis";
  description = ''
    Wireshark captures and dissects network traffic down to the protocol
    layer — follow a TCP stream, filter on a field with its display-filter
    language, and decode protocols the kernel just handed it as raw bytes.
  '';
  docs = "https://www.wireshark.org/docs/";
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
