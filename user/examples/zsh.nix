{ config, lib, pkgs, ... }:

# ── HOW TO USE ────────────────────────────────────────────────────────────────
# Add this file to your user/home.nix imports list:
#
#   imports = [ ./examples/zsh.nix ];
#
# This appends a welcome banner and extra aliases on top of the defaults
# already defined in home.nix. You do not lose the existing aliases or
# zsh config — this only adds to them.
# ─────────────────────────────────────────────────────────────────────────────

{
  # ── Welcome banner ────────────────────────────────────────────────────────
  # lib.mkAfter appends this block after the existing initContent in home.nix.
  # The banner prints every time a new terminal opens (outside of tmux).
  programs.zsh.initContent = lib.mkAfter ''
    # ── AnNIXion banner ───────────────────────────────────────────────────
    echo ""
    echo "  \e[1;31m █████╗ ███╗   ██╗███╗  ██╗██╗██╗  ██╗██╗ ██████╗ ███╗  \e[0m"
    echo "  \e[1;31m██╔══██╗████╗  ██║████╗ ██║██║╚██╗██╔╝██║██╔═══██╗████╗ \e[0m"
    echo "  \e[1;31m███████║██╔██╗ ██║██╔██╗██║██║ ╚███╔╝ ██║██║   ██║██╔██╗\e[0m"
    echo "  \e[1;31m██╔══██║██║╚██╗██║██║╚████║██║ ██╔██╗ ██║██║   ██║██║╚██╗\e[0m"
    echo "  \e[1;31m██║  ██║██║ ╚████║██║ ╚███║██║██╔╝╚██╗██║╚██████╔╝██║ ╚██╗\e[0m"
    echo "  \e[1;31m╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚══╝╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝\e[0m"
    echo ""
    echo "  \e[0;90mhost\e[0m  $(hostname)"
    echo "  \e[0;90mdate\e[0m  $(date '+%A %d %B %Y  %H:%M')"
    echo "  \e[0;90mip  \e[0m  $(ip -4 addr show scope global 2>/dev/null | awk '/inet/{print $2}' | head -1)"
    echo ""
  '';

  # ── Extra aliases ─────────────────────────────────────────────────────────
  # These are merged with the defaults in home.nix at the key level, so
  # existing aliases (ll, gs, gp, gl, rebuild, enix, emod, euser, ehome) are kept unless
  # you redefine one here with the same name.
  programs.zsh.shellAliases = {
    # Network recon shortcuts
    pingsweep = "nmap -sn";       # usage: pingsweep 192.168.1.0/24
    ports     = "nmap -sV -sC";   # usage: ports 10.0.0.1

    # Quick recon helpers
    myip      = "curl -s https://ifconfig.me && echo";
    localip   = "ip -4 addr show scope global | awk '/inet/{print $2}'";

    # Tool shortcuts
    msf       = "msfconsole";
    bsuite    = "burpsuite";

    # Add your own below
  };
}