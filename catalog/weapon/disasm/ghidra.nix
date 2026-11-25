# NSA software reverse engineering framework
{ bodies }:
{
  package = p: p.ghidra;
  name = "Ghidra";
  genericName = "Reverse Engineering Suite";
  comment = "NSA software reverse engineering framework";
  description = ''
    Ghidra disassembles and decompiles binaries across a wide range of
    architectures, with a scriptable analysis pipeline and a decompiler
    view that reconstructs C-like pseudocode from machine code.
  '';
  docs = "https://github.com/NationalSecurityAgency/ghidra/wiki";
  snippets = [
    {
      label = "Headless batch analysis (no GUI)";
      command = "analyzeHeadless <project_dir> <project_name> -import <binary> -deleteProject";
    }
  ];
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
