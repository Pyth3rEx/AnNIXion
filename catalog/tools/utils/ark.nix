# Archive Manager
_: {
  package = null; # ships with the desktop, not this module
  name = "Ark";
  genericName = "Archive Manager";
  exec = "ark";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "ark" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M1.8 5.4 22.2 4.9q.4 8.4-.1 16.8l-19.7.4C1.5 16.5 1.4 11 1.8 5.4z"/>
      <path d="M1.9 10.4q10.1-.5 20.2 0"/>
      <path d="M9.6 5.2q.2 2.6 0 5.2M14.4 5.1q.2 2.7 0 5.4"/>
      <path d="M11.8 14.4q.3 2.4.1 4.8"/>
    '';
  };
}
