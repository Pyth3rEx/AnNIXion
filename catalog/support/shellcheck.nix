# VSCodium's shellcheck extension bundles its own binary, which won't run on
# NixOS; provide one on PATH instead.
# Installed system-wide but never shown: no menu entry, no mark.
_: {
  package = p: p.shellcheck;
}
