# user/home.nix
# ─────────────────────────────────────────────────────────────────────────────
# USER ENVIRONMENT OVERRIDES
#
# This file is merged AFTER home.nix. Every option in home.nix uses
# lib.mkDefault (priority 1000), so anything you write here at normal
# priority (100) wins automatically — no lib.mkForce needed.
#
# ── Quick start ──────────────────────────────────────────────────────────────
# 1. Uncomment the example imports below to activate them.
# 2. Edit the values inside each example file (git name, email, etc.).
# 3. Run: sudo nixos-rebuild switch --flake .#AnNIXion
#
# ── What belongs here ────────────────────────────────────────────────────────
#   • Your real git name and email
#   • Extra shell aliases or zsh config
#   • Extra user-level packages (installed only for you, not system-wide)
#   • Changes to tmux, xterm appearance, KDE shortcuts
#   • Any Home Manager option: https://nix-community.github.io/home-manager/options.xhtml
# ─────────────────────────────────────────────────────────────────────────────
{ config, lib, pkgs, ... }:

{
  imports = [
    # Uncomment to activate — edit each file to fill in your own values.
    # ./examples/git.nix    # sets your git name, email, and signing key
    # ./examples/zsh.nix    # adds a welcome banner and recon aliases
  ];

  # Your own overrides go below this line.
  # See user/README.md for examples of what you can set here.
}