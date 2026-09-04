# Domain Lookup
_: {
  package = p: p.whois;
  name = "Whois";
  genericName = "Domain Lookup";
  exec = "whois";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "passive";
    body = ''
      <path d="M1.9 4.2 22.1 3.7c.6 5.3.6 10.6.1 15.9l-20.1.4C1.5 14.8 1.5 9.5 1.9 4.2z"/>
      <path d="M10.6 10.6c0 1.6-1.3 2.8-2.9 2.8-1.5 0-2.7-1.3-2.6-2.9 0-1.5 1.3-2.6 2.8-2.6s2.7 1.2 2.7 2.7"/>
      <path d="M3.9 16.9c1-1.9 2.4-2.9 4-2.9 1.5 0 2.9 1 3.9 2.8"/>
      <path d="M14.1 9.1q2.8-.3 5.6.1M14.2 12.4q2.7-.3 5.4.1M14.1 15.7q1.9-.2 3.7 0"/>
      <path d="M5.4 20.1v3.1"/>
    '';
  };
}
