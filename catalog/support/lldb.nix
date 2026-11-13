# CLI debugger, and the backend Ghidra's Debugger plugin and VSCodium's
# codelldb (home/apps/vscodium.nix) launch when told to use it.
# Installed system-wide but never shown: no menu entry, no mark.
_: {
  package = p: p.lldb;
}
