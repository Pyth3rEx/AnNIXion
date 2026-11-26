# Web server fingerprinting and technology detection
_: {
  package = p: p.whatweb;
  name = "WhatWeb";
  genericName = "Web Recon";
  comment = "Web server fingerprinting and technology detection";
  description = ''
    WhatWeb fingerprints a web target's technology stack — CMS, frameworks,
    JavaScript libraries, server software and version strings — from over
    a thousand passive and active detection plugins.
  '';
  docs = "https://github.com/urbanadventurer/WhatWeb/wiki";
  snippets = [
    {
      label = "Fingerprint a site";
      command = "whatweb <URL>";
    }
    {
      label = "Aggressive scan, verbose plugin output";
      command = "whatweb -a 3 -v <URL>";
    }
  ];
  exec = "whatweb";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "probe";
    body = ''
      <path d="M1.8 3.4 22.2 2.9c.4 3.9.5 7.8.2 11.7l-8.2.3"/>
      <path d="M1.8 3.4q-.3 5.6 0 11.2 4.8.3 9.6.2"/>
      <path d="M2 7.4q10 -.5 20 0"/>
    '';
    over = ''
      <path d="M21.4 18.2c0 2.4-2 4.3-4.4 4.2-2.3 0-4.2-2-4.1-4.4 0-2.3 2-4.1 4.3-4 2.3 0 4.2 1.9 4.2 4.2"/>
      <path d="M20 20.9 22.8 23"/>
    '';
  };
}
