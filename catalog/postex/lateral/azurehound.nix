# Go data exporter for BloodHound — pulls Entra ID (users, groups, apps,
# role assignments) over the Graph API with an already-valid credential or
# device-code login. Its output uploads into BloodHound CE's UI the same
# way BloodHound.py's on-prem collection does.
_: {
  package = p: p.azurehound;
  name = "AzureHound";
  genericName = "Entra ID Data Collector";
  comment = "Collects Entra ID roles, groups and app data for the BloodHound CE graph";
  exec = "azurehound";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "probe";
    body = ''
      <path d="M5.4 14.2c-2.3-.3-3.6-2.6-2.8-4.7.7-1.8 2.7-2.6 4.5-2 .3-2.4 2.4-4.1 4.8-3.8 2.1.2 3.7 1.9 3.9 4 1.9-.6 4 .5 4.5 2.4.5 1.9-.6 3.8-2.5 4.3"/>
      <path d="M9.6 14.4v4.2M13.4 14.3v3.4"/>
      <circle cx="9.6" cy="19.6" r="1.1" fill="@c@" stroke="none"/>
    '';
  };
}
