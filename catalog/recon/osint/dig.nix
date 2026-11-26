# DNS Lookup
_: {
  package = p: p.dnsutils;
  name = "dig";
  genericName = "DNS Lookup";
  description = ''
    dig queries DNS directly, bypassing whatever the system resolver would
    cache — look up a record type, follow a trace from the root, or do a
    reverse lookup from an IP.
  '';
  docs = "https://bind9.readthedocs.io/en/latest/manpages.html";
  snippets = [
    {
      label = "Basic A record lookup";
      command = "dig <domain>";
    }
    {
      label = "Any record type, terse output";
      command = "dig +short <domain> ANY";
    }
    {
      label = "Reverse lookup from an IP";
      command = "dig -x <IP>";
    }
  ];
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
