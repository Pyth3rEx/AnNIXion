# Terminal running a root login shell, on a red background
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "Konsole (root)";
  genericName = "Root Terminal";
  comment = "Terminal running a root login shell, on a red background";
  exec = "konsole -name konsole-root --profile Root -e sudo -i";
  launch = "gui"; # runs directly
  wmClass = "konsole-root";
  mark = {
    class = "elevated";
    body = bodies.terminal;
  };
}
