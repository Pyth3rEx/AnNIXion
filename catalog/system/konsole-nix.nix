# Terminal inside the flake dev shell, where the checks run
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "Konsole (Nix shell)";
  genericName = "Nix Dev Shell";
  comment = "Terminal inside the flake dev shell, where the checks run";
  exec = "nix develop @home@/.dotfiles";
  launch = "named"; # konsole under its own WM_CLASS
  wmName = "konsole-nix";
  wmClass = "konsole-nix";
  mark = {
    class = "nixenv";
    body = bodies.terminal;
  };
}
