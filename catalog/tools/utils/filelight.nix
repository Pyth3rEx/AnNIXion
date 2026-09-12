# Disk Usage Analyzer
_: {
  package = null; # ships with the desktop, not this module
  name = "Filelight";
  genericName = "Disk Usage Analyzer";
  exec = "filelight";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "filelight" ];
  mark = {
    class = "utility";
    body = ''
      <circle cx="12" cy="12" r="2.4" fill="@c@" stroke="none"/>
      <path d="M5.4 8.4c2.6-4.4 8.2-6 12.8-3.6"/>
      <path d="M19.8 8.6c1.9 4.6.1 9.9-4.2 12.4"/>
      <path d="M12.6 21.8C7.6 21.5 3.4 17.4 3.2 12.4"/>
    '';
  };
}
