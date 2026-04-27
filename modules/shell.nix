{ config, lib, pkgs, ... }:

{
  # ============================================================
  # SHELL & TERMINAL — SYSTEM LEVEL
  # ============================================================

  # Enable zsh system-wide and set it as the default shell for operator.
  programs.zsh.enable = lib.mkDefault true;
  users.users.operator.shell = pkgs.zsh;
}