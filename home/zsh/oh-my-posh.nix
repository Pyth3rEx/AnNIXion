# The prompt. Segment layout and colours are documented in docs/zsh.md.
_:

{
  # nix-shell drops into bash and sources ~/.bashrc, so the prompt needs it.
  programs.bash.enable = true;

  programs.oh-my-posh = {
    enable = true;
    settings = import ./omp-theme.nix;
  };
}
