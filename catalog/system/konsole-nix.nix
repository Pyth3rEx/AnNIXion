# Terminal inside the flake dev shell, where the checks run
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "Konsole (Nix shell)";
  genericName = "Nix Dev Shell";
  comment = "Terminal inside the flake dev shell, where the checks run";
  description = "Drops into `nix develop` for this flake — nixfmt, statix, deadnix and nil are on PATH there, the same shell CI's lint check runs.";
  docs = "https://docs.kde.org/?application=konsole";
  exec = "nix develop @home@/.dotfiles";
  launch = "named"; # konsole under its own WM_CLASS
  wmName = "konsole-nix";
  wmClass = "konsole-nix";
  mark = {
    class = "nixenv";
    body = bodies.terminal;
  };
}
