# Software defined radio receiver
{ bodies }:
{
  package = p: p.gqrx;
  name = "Gqrx";
  genericName = "SDR Receiver";
  comment = "Software defined radio receiver";
  exec = "gqrx";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "gqrx" ];
  mark = {
    class = "probe";
    body = bodies.gqrx;
  };
}
