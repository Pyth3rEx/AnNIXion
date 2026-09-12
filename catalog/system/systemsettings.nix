# System Configuration
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "System Settings";
  genericName = "System Configuration";
  exec = "systemsettings";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [
    "systemsettings"
    "preferences-system" # generic
  ];
  mark = {
    class = "utility";
    body = bodies.systemsettings;
  };
}
