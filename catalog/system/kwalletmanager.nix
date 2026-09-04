# Manage stored passwords and secrets
_: {
  package = null; # ships with the desktop, not this module
  name = "KWallet Manager";
  genericName = "Credential Store";
  comment = "Manage stored passwords and secrets";
  exec = "kwalletmanager";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "kwalletmanager" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M1.8 5.4 20.2 4.9c.5 5.4.5 10.8.1 16.2l-18.4.4C1.4 16.1 1.4 10.7 1.8 5.4z"/>
      <path d="M2 5.2q7.4-2.4 14.9-4.4.5 2.2.7 4.4"/>
      <circle cx="19.2" cy="13.2" r="1.4" fill="@c@" stroke="none"/>
    '';
    over = ''
      <path d="M22.4 10.4q.2 2.8 0 5.6-3.1.3-6.2 0-.3-2.8 0-5.6z"/>
    '';
  };
}
