# Interactive process viewer
_: {
  package = null; # ships with the desktop, not this module
  name = "htop";
  genericName = "System Monitor";
  comment = "Interactive process viewer";
  exec = "htop";
  launch = "term"; # konsole, closes with the tool
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "htop" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M1.8 21.6q10.2-.5 20.4 0"/>
      <path d="M4.4 21.4q.3-4.6.1-9.2M9.4 21.4q.3-8.2.1-16.4M14.4 21.3q.3-6.2.1-12.4M19.4 21.3q.3-3.4.1-6.8"/>
    '';
  };
}
