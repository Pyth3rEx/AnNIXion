# Code Editing. Redefined.
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "VSCodium";
  genericName = "Text Editor";
  comment = "Code Editing. Redefined.";
  description = "VSCodium is a telemetry-free build of VS Code — same editor, extensions and debugger, built from the open-source code without Microsoft's branding or telemetry.";
  docs = "https://code.visualstudio.com/docs";
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
