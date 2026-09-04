# Menu node: RF / Signal Intel
{ bodies }:
{
  order = 3;
  menuName = "RF Signal Intel";
  label = "RF / Signal Intel";
  directory = "annixion-1-recon-rf.directory";
  note = ''
    No "/" in a menu Name: it is a path separator, so the slash
    invents a parent menu. The label comes from the .directory.
  '';
  category = "X-AnNIXion-Recon-RF";
  mark = {
    class = "probe";
    body = bodies.gqrx;
  };
}
