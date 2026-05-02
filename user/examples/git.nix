{ config, lib, pkgs, ... }:

# ── HOW TO USE ────────────────────────────────────────────────────────────────
# Add this file to your user/home.nix imports list:
#
#   imports = [ ./examples/git.nix ];
#
# Then fill in your real name and email below.
# ─────────────────────────────────────────────────────────────────────────────

{
  programs.git.settings.userName  = "Your Name";
  programs.git.settings.userEmail = "you@example.com";

  programs.git.settings.extraConfig = {
    init.defaultBranch = "main";
    pull.rebase        = false;

    # Useful for security work — always verify what you're pushing
    push.default = "current";

    # Nicer diffs
    diff.colorMoved = "zebra";
  };

  # ── Optional: GPG commit signing ──────────────────────────────────────────
  # Get your key ID with: gpg --list-secret-keys --keyid-format LONG
  #
  # programs.git.signing = {
  #   key            = "YOUR_GPG_KEY_ID";
  #   signByDefault  = true;
  # };
}
