# Text Editor
_: {
  package = null; # ships with the desktop, not this module
  name = "Kate";
  genericName = "Text Editor";
  exec = "kate";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "kate" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M3.4 2.2 14.6 1.8q.4 10 0 20l-11.1.4C3 15.5 3 8.9 3.4 2.2z"/>
      <path d="M6.6 6.4q4.2-.4 8.4 0M6.7 10.1q2.8-.3 5.6 0"/>
    '';
    over = ''
      <path d="M21.4 7.6 12.2 17.2l-3.6 1 1.1-3.5 9.2-9.6z"/>
    '';
  };
}
