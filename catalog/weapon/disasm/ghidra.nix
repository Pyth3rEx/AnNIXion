# NSA software reverse engineering framework
{ bodies }:
{
  package = p: p.ghidra;
  name = "Ghidra";
  genericName = "Reverse Engineering Suite";
  comment = "NSA software reverse engineering framework";
  exec = "ghidra";
  launch = "gui"; # runs directly
  # Earns a place under a second phase as well.
  alsoIn = [ "re/disasm" ];
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "ghidra" ];
  mark = {
    class = "reverse";
    body = bodies.ghidra;
  };
}
