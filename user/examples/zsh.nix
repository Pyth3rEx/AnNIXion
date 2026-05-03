# user/examples/zsh.nix
# ─────────────────────────────────────────────────────────────────────────────
# Example: ZSH customization
#
# To activate: uncomment in user/home.nix:
#   imports = [ ./examples/zsh.nix ];
# ─────────────────────────────────────────────────────────────────────────────
{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    shellAliases = {
      # ── Recon shortcuts ───────────────────────────────────────
      hosts  = "nmap -sn";         # host discovery
      ports  = "nmap -sV --open";  # port/service scan
      dns    = "dig +short";       # quick DNS lookup
    };

    initContent = lib.mkAfter ''
      # ── Welcome banner override ───────────────────────────────
      # Uncomment to append a line after the default AnNIXion banner.
      # echo "  op: $(whoami)  |  $(date '+%H:%M')"
    '';
  };
}