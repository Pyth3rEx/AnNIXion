# Menu node: Active Scanning
{ bodies }:
{
  order = 2;
  menuName = "Active Scanning";
  label = "Active Scanning";
  directory = "annixion-1-recon-scanning.directory";
  category = "X-AnNIXion-Recon-Scanning";
  mark = {
    class = "probe";
    body = ''
      <path d="M3.2 14c3.6-.2 6.8 2.9 7 6.7"/>
      <path d="M3 8.3c7 .1 12.7 5.9 13 12.5"/>
      <path d="M3.1 2.6c10.2.4 18.4 8.7 18.8 18.5"/>
    '';
    over = bodies.nmapOver;
  };
}
