# home/desktop/seclists-explorer.nix — the `seclists` command behind the
# "SecLists" menu entry (catalog/exploit/creds/seclists.nix).
#
# This used to be a programs.zsh.shellAliases entry. An alias only exists once
# ~/.zshrc has been sourced into an interactive shell, but the menu's "hold"
# launcher runs it as `konsole -e zsh -c "seclists; exec zsh"` — zsh -c is
# non-interactive and never sources .zshrc, so the alias was invisible there
# and the menu click failed with "command not found: seclists" even though
# typing the same word at an already-open prompt worked fine (#126). A real
# binary on PATH resolves the same way from both places.
{ pkgs, ... }:

let
  seclists = pkgs.writeShellApplication {
    name = "seclists";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      SECLISTS_PATH="''${SECLISTS_PATH:-/run/current-system/sw/share/wordlists/seclists/}"
      printf '=== Seclists Explorer ===\n\n%s\n\nThis is the Seclists wordlists directory (read-only in Nix store). Listing top-level folders:\n\n' "$SECLISTS_PATH"
      # shellcheck disable=SC2012 # find has no --group-directories-first equivalent
      ls -la --group-directories-first "$SECLISTS_PATH" 2>/dev/null | awk '/^d/ {print}'
    '';
  };
in
{
  home.packages = [ seclists ];
}
