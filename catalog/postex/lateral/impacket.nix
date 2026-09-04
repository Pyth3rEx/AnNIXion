# Python tools for Windows protocols — run impacket-<tool>
{ bodies }:
{
  package = p: p.python313Packages.impacket;
  name = "Impacket";
  genericName = "Windows Post-Exploitation Suite";
  comment = "Python tools for Windows protocols — run impacket-<tool>";
  exec = "konsole";
  launch = "gui"; # runs directly
  mark = {
    class = "offensive";
    body = bodies.impacket;
  };
}
