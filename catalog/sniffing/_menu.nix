# Menu node: 10. Sniffing & Analysis
{ bodies }:
{
  order = 10;
  menuName = "10. Sniffing &amp; Analysis";
  label = "10. Sniffing & Analysis";
  # The label carries a "/", which a menu Name would read as a path separator.
  directory = "annixion-10-sniffing.directory";
  category = "X-AnNIXion-Sniffing";
  mark = {
    class = "forensic";
    body = bodies.wireshark;
  };
}
