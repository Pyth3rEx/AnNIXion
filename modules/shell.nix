# Zsh for every login, and the oh-my-posh prompt for the shells Home Manager
# does not own — root, mainly.
{
  lib,
  pkgs,
  ...
}:

let
  theme = (pkgs.formats.json { }).generate "oh-my-posh.json" (import ../home/zsh/omp-theme.nix);

  init = shell: ''eval "$(${lib.getExe pkgs.oh-my-posh} init ${shell} --config ${theme})"'';
in

{
  programs.zsh.enable = lib.mkDefault true;

  # 900 beats the mkDefault bashInteractive nixpkgs sets, without blocking a
  # plain override in user/configuration.nix. Root follows it too.
  users.defaultUserShell = lib.mkOverride 900 pkgs.zsh;

  # Nothing else starts a prompt in bash, so this one is unguarded.
  programs.bash.promptInit = lib.mkDefault (init "bash");

  # Home Manager starts the prompt for users it manages, and its ~/.zshrc runs
  # after this, so skip them rather than initialising twice.
  programs.zsh.promptInit = lib.mkDefault ''
    if [ ! -e "$HOME/.config/oh-my-posh/config.json" ]; then
      ${init "zsh"}
    fi
  '';
}
