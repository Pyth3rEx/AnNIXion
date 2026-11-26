# Network exploration and security auditing
{ bodies }:
{
  package = p: p.nmap;
  name = "Nmap";
  genericName = "Network Scanner";
  comment = "Network exploration and security auditing";
  description = ''
    Nmap discovers hosts and services on a network by sending crafted packets
    and interpreting the responses: host discovery, port scanning, service
    and version detection, OS fingerprinting, and scriptable checks via the
    Nmap Scripting Engine (NSE).
  '';
  docs = "https://nmap.org/book/man.html";
  snippets = [
    {
      label = "Service/version scan with default scripts";
      command = "nmap -sV -sC <IP>";
    }
    {
      label = "All 65535 TCP ports";
      command = "nmap -p- <IP>";
    }
    {
      label = "OS detection, version, scripts, traceroute";
      command = "nmap -A <IP>";
    }
    {
      label = "Quick UDP sweep of common ports";
      command = "nmap -sU --top-ports 20 <IP>";
    }
  ];
  exec = "nmap";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "probe";
    body = ''
      <path d="M3.2 14c3.6-.2 6.8 2.9 7 6.7"/>
      <path d="M3 8.3c7 .1 12.7 5.9 13 12.5"/>
      <path d="M3.1 2.6c10.2.4 18.4 8.7 18.8 18.5"/>
      <path d="M10.3 20.9v2.7"/>
    '';
    over = bodies.nmapOver;
  };
}
