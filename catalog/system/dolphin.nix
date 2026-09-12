# File Manager
_: {
  package = null; # ships with the desktop, not this module
  name = "Dolphin";
  genericName = "File Manager";
  exec = "dolphin";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "org.kde.dolphin" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M1.8 4.4 9.4 4l2.2 3.2q5.3-.3 10.6 0 .4 6.9-.1 13.8l-20.1.4C1.5 15 1.4 9.7 1.8 4.4z"/>
      <path d="M2 11.4q10 -.5 20 0"/>
    '';
  };
}
