# Memory acquisition and forensics framework
{ bodies }:
{
  package = p: p.volatility3;
  name = "Volatility 3";
  genericName = "Memory Forensics";
  comment = "Memory acquisition and forensics framework";
  exec = "vol";
  launch = "term"; # konsole, closes with the tool
  mark = {
    class = "forensic";
    body = ''
      <path d="M1.2 6.4 22.8 5.9c.5 3.4.5 6.8.1 10.2l-21.5.4c-.5-3.3-.6-6.7-.2-10.1z"/>
      <path d="M5 15.6q.2 1.8 0 3.5M9.6 15.5q.2 1.8 0 3.5M14.2 15.5q.2 1.8 0 3.5M18.9 15.4q.2 1.8 0 3.5"/>
      <path d="M9.7 19.1v3.1"/>
    '';
    over = bodies.volatilityOver;
  };
}
