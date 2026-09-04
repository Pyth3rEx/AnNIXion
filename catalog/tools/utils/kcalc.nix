# Calculator
_: {
  package = null; # ships with the desktop, not this module
  name = "KCalc";
  genericName = "Calculator";
  exec = "kcalc";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [
    "accessories-calculator" # generic
  ];
  mark = {
    class = "utility";
    body = ''
      <path d="M4.4 1.8 19.6 1.4q.4 10.2 0 20.4l-15.1.4C4 15 4 8.4 4.4 1.8z"/>
      <path d="M7.4 6.2q4.9-.4 9.8 0"/>
      <path d="M7.6 12.4q1.4-.2 2.8 0M13.4 12.3q1.5-.2 3 0M7.7 16.6q1.4-.2 2.8 0M13.5 16.5q1.5-.2 3 0"/>
    '';
  };
}
