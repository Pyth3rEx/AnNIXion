# DNS Lookup
_: {
  package = p: p.dnsutils;
  name = "dig";
  genericName = "DNS Lookup";
  exec = "dig";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "passive";
    body = ''
      <path d="M12 1.6q.3 4.1.1 8.2"/>
      <path d="M3.4 13.9q8.7-.6 17.4 0"/>
      <path d="M12.1 9.8q-4.4.2-8.7 0-.2 2 0 4.1M12.1 9.8q4.4.2 8.7 0 .2 2 0 4.1"/>
      <circle cx="12" cy="18.4" r="2.4" fill="@c@" stroke="none"/>
      <path d="M3.6 14q-.2 2 0 4M20.6 14q-.2 2 0 4"/>
    '';
  };
}
