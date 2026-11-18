# Attack-path graph over data a collector (SharpHound) already pulled —
# reads and visualises, never reaches the target itself.
_: {
  package = p: p.bloodhound-ce;
  name = "BloodHound CE";
  genericName = "AD Attack Path Mapping";
  comment = "Graphs Active Directory attack paths from collected session, ACL and membership data";
  exec = "bloodhound-ce";
  launch = "gui"; # runs directly
  mark = {
    class = "passive";
    body = ''
      <path d="M6.9 20.3c-.9 1.3-2.7 1.6-4 .6-1.2-1-1.4-2.8-.4-4 1-1.2 2.8-1.3 4-.3"/>
      <path d="M19.9 20.3c-.9 1.3-2.7 1.6-4 .6-1.2-1-1.4-2.8-.4-4 1-1.2 2.8-1.3 4-.3"/>
      <path d="M13.6 13.2c-.8 1.1-2.3 1.3-3.4.4-1-.8-1.2-2.4-.3-3.4.8-1 2.4-1.2 3.4-.3"/>
      <path d="M5.3 17.1 10.8 13.5M18.6 17.1 13.4 13.6M12.4 10.3 12 5.7"/>
      <circle cx="12" cy="4.2" r="1.8" fill="@c@" stroke="none"/>
    '';
  };
}
