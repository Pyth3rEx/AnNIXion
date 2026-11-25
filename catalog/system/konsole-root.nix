# Terminal running a root login shell, on a red background
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "Konsole (root)";
  genericName = "Root Terminal";
  comment = "Terminal running a root login shell, on a red background";
  description = "A root login shell via `sudo -i`, in a Konsole profile coloured red so it is never mistaken for an unprivileged terminal.";
  docs = "https://docs.kde.org/?application=konsole";
  exec = "konsole -name konsole-root --profile Root -e sudo -i";
  launch = "gui"; # runs directly
  wmClass = "konsole-root";
  mark = {
    class = "elevated";
    body = bodies.terminal;
  };
}
