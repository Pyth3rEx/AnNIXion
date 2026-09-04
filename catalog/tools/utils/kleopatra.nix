# OpenPGP and X.509 certificate management
_: {
  package = null; # ships with the desktop, not this module
  name = "Kleopatra";
  genericName = "PGP & Certificate Manager";
  comment = "OpenPGP and X.509 certificate management";
  exec = "kleopatra";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "kleopatra" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M18.4 8.6c0 3.6-2.9 6.5-6.5 6.4-3.5 0-6.3-3-6.2-6.6C5.8 4.9 8.7 2.1 12.2 2.2c3.5 0 6.2 2.9 6.2 6.4"/>
      <path d="M9.2 8.6 11.4 11l3.8-4.4"/>
      <path d="M8.4 14.6q-.4 4.2-.8 8.4l4.4-2.6 4.4 2.6q-.4-4.2-.8-8.4"/>
    '';
  };
}
