# The prompt. Segment layout and colours are documented in docs/zsh.md.
_:

{
  programs.oh-my-posh = {
    enable = true;
    settings = import ./omp-theme.nix;
  };
}
