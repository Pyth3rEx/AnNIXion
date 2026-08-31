# Git for every user, and the gh credential helper that pushes need.
{
  lib,
  pkgs,
  ...
}:

{
  # /etc/gitconfig, not ~/.gitconfig: it applies to a fresh install with no
  # manual step, and a user's own config still overrides it.
  programs.git.enable = lib.mkDefault true;

  # "gh auth setup-git" writes the store path of whichever gh ran it, and the
  # next garbage collection leaves that path dangling — the helper then fails
  # to start and every push loses its credentials. This path is part of the
  # system closure, so it cannot be collected, and a rebuild refreshes it.
  programs.git.config = {
    credential."https://github.com".helper = "${lib.getExe pkgs.gh} auth git-credential";
    credential."https://gist.github.com".helper = "${lib.getExe pkgs.gh} auth git-credential";
  };
}
