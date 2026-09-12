# Terminal Emulator
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "Konsole";
  genericName = "Terminal Emulator";
  exec = "konsole";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [
    "utilities-terminal" # generic
  ];
  mark = {
    class = "utility";
    body = bodies.terminal;
  };
}
