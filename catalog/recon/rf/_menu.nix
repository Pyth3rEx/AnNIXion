# Menu node: RF / Signal Intel
{ bodies }:
{
  order = 3;
  menuName = "RF Signal Intel";
  label = "RF / Signal Intel";
  # The label carries a "/", which a menu Name would read as a path separator.
  directory = "annixion-1-recon-rf.directory";
  category = "X-AnNIXion-Recon-RF";
  mark = {
    class = "probe";
    body = bodies.gqrx;
  };
}
