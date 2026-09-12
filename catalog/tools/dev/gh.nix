# Git CLI
_: {
  package = null; # ships with the desktop, not this module
  name = "GitHub CLI";
  genericName = "Git CLI";
  exec = "gh";
  launch = "term"; # konsole, closes with the tool
  mark = {
    class = "utility";
    body = ''
      <path d="M1.6 4.4 22.4 3.9c.5 5.4.5 10.8.1 16.2l-20.7.4C1.3 15.2 1.2 9.8 1.6 4.4z"/>
      <circle cx="7.4" cy="8.8" r="1.5" fill="@c@" stroke="none"/>
      <circle cx="7.4" cy="16" r="1.5" fill="@c@" stroke="none"/>
      <circle cx="16.4" cy="11.4" r="1.5" fill="@c@" stroke="none"/>
      <path d="M7.4 10.3q-.2 2.1 0 4.2"/>
      <path d="M16.4 12.9q.2 1.9-2 2.7-2.5.9-6.1.4"/>
    '';
  };
}
