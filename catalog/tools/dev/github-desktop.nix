# Git GUI
_: {
  package = null; # ships with the desktop, not this module
  name = "GitHub Desktop";
  genericName = "Git GUI";
  exec = "github-desktop";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "github-desktop" ];
  mark = {
    class = "utility";
    body = ''
      <circle cx="6" cy="4.6" r="2.6" fill="@c@" stroke="none"/>
      <circle cx="6" cy="19.4" r="2.6" fill="@c@" stroke="none"/>
      <circle cx="18.2" cy="9.4" r="2.6" fill="@c@" stroke="none"/>
      <path d="M6 7.2q-.2 4.8 0 9.6"/>
      <path d="M18.2 12q.2 4-3.4 6.2-3.4 2-8.5 1.3"/>
    '';
  };
}
