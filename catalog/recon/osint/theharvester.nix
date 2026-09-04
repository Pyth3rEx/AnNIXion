# Email, domain and IP intelligence gathering
_: {
  package = p: p.theharvester;
  name = "theHarvester";
  genericName = "OSINT Harvester";
  comment = "Email, domain and IP intelligence gathering";
  exec = "theHarvester";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "passive";
    body = ''
      <path d="M16 12.7c-1.1 3.2-4.6 5-7.9 4.2C4.7 16 2.7 12.5 3.6 9.2 4.4 6 7.7 4 11 4.8c3 .7 5 3.4 5 6.4"/>
      <path d="M6.6 8.2q2.9-.5 5.7.2M6.7 11.3q1.8-.4 3.6.1"/>
      <path d="M14.2 14.7 21.9 22.2"/>
      <path d="M9.4 17.5v3.7"/>
    '';
  };
}
