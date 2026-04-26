{ config, lib, pkgs, ... }:

{
  # ============================================================
  # SHELL & TERMINAL — SYSTEM LEVEL
  # ============================================================

  # Enable zsh system-wide and set it as the default shell for operator.
  # Without this NixOS option, xterm ignores the home.nix zsh config entirely —
  # the system won't recognise zsh as a valid login shell.
  programs.zsh.enable = lib.mkDefault true;
  users.users.operator.shell = pkgs.zsh;

  # xterm — the terminal emulator configured as the KDE default terminal.
  # Installed at the system level so it is available before any user
  # session starts (e.g. from the SDDM login screen or xrdp session).
  environment.systemPackages = with pkgs; [
    xterm
  ];
}