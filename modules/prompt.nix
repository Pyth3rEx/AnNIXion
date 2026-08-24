# The oh-my-posh prompt for shells Home Manager does not own — root, mainly.
{
  lib,
  pkgs,
  ...
}:

let
  theme = (pkgs.formats.json { }).generate "oh-my-posh.json" (import ../home/zsh/omp-theme.nix);

  # Home Manager already starts the prompt for users it manages, and its
  # ~/.zshrc runs after this, so skip them rather than initialising twice.
  promptInit = shell: ''
    if [ ! -e "$HOME/.config/oh-my-posh/config.json" ]; then
      eval "$(${lib.getExe pkgs.oh-my-posh} init ${shell} --config ${theme})"
    fi
  '';
in

{
  programs.bash.promptInit = lib.mkDefault (promptInit "bash");
  programs.zsh.promptInit = lib.mkDefault (promptInit "zsh");
}
