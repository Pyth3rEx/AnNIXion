# Code Editing. Redefined.
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "VSCodium";
  genericName = "Text Editor";
  comment = "Code Editing. Redefined.";
  exec = "codium";
  launch = "gui"; # runs directly
  wmClass = "vscodium";
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "vscodium" ];
  mark = {
    class = "utility";
    body = bodies.vscodium;
  };
}
