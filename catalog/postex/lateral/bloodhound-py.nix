# Python ingestor for BloodHound, built on Impacket. Runs from this box
# against on-prem AD over LDAP/SMB/Kerberos with an already-valid domain
# account; its output zip uploads into BloodHound CE's own UI. SharpHound
# itself stays out — a Windows-only .NET binary with nothing to run on this
# box, and it already ships inside BloodHound CE's own container image.
_: {
  package = p: p.bloodhound-py;
  name = "BloodHound.py";
  genericName = "AD Data Collector";
  comment = "Collects AD session, ACL and membership data for the BloodHound CE graph";
  exec = "bloodhound-python";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "probe";
    body = ''
      <path d="M3.2 4.6q8.8 1.4 17.6-.2"/>
      <path d="M3.4 4.7Q8.2 10.5 11 15.7M20.6 4.4Q15.8 10.2 13 15.6"/>
      <path d="M11 15.7v3M13 15.6v3.1"/>
      <path d="M9.6 19q2 1.7 4.8.1"/>
      <circle cx="11.6" cy="9.6" r="1" fill="@c@" stroke="none"/>
    '';
  };
}
