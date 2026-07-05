{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ───────────────────────────────────────────────────────────────────────────
  # Zsh — core settings
  # ───────────────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # grey inline suggestions as you type
    syntaxHighlighting.enable = true;  # red = invalid, green = valid command
    enableCompletion = true;
    autocd = true;                     # type a directory name to cd into it

    # ── oh-my-zsh framework ─────────────────────────────────────────────────
    # Only bundled plugins go here — external packages (autosuggestions,
    # syntax-highlighting) are handled by the HM options above.
    oh-my-zsh = {
      enable = true;
      theme = "";  # oh-my-posh owns the prompt; leave this empty
      plugins = [
        "git"              # git aliases (gst, gco, gp …) + status info
        "docker"           # docker subcommand completion
        "colorize"         # ccat / cless — syntax-highlighted file viewing (needs chroma pkg)
        "z"                # frecency directory jumping: `z proj` → cd ~/…/project
        "sudo"             # ESC ESC — prepend sudo to the current/previous command
        "extract"          # `x archive.tar.gz` — one command for any archive format
        "history"          # h = history  hs = grep history  hsi = case-insensitive
        "nmap"             # nmap shortcuts: nmap_open_ports, nmap_full_udp, nmap_os …
        "rsync"            # rsync-copy / rsync-move with progress bar
      ];
    };

    # ── Aliases ─────────────────────────────────────────────────────────────
    shellAliases = {
      # ── System ─────────────────────────────────────────────
      ll = "ls -la";
      grep = "grep --color=auto";
      cat = "bat";

      # ── NixOS rebuild ──────────────────────────────────────
      rebuild = "sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure && kbuildsycoca6";
      upgrade = "nix flake update --flake ~/.dotfiles && sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure && kbuildsycoca6";
      update  = "nix flake update --flake ~/.dotfiles";

      # ── Git ────────────────────────────────────────────────
      gs = "git status";
      gp = "git push";
      gl = "git pull";

      # ── Network / OSINT ────────────────────────────────────
      ip_out   = "curl -s https://ifconfig.me && echo";
      ip_local = "ip -4 addr show scope global | awk '/inet/{print $2}'";
      myip     = "ip -4 addr | awk '/inet/ && !/127.0.0.1/{printf \"%-12s %s\\n\", $NF\":\", $2}'";
      ports    = "ss -tulnp";
      vpn      = "ip link 2>/dev/null | awk '/tun[0-9]|wg[0-9]|vpn/{printf \"VPN ACTIVE: %s\\n\", $2}' | grep . || echo 'No VPN detected'";

      # ── Quick config edit ──────────────────────────────────
      enix  = "kate ~/.dotfiles/flake.nix";
      emod  = "kate ~/.dotfiles/modules/";
      euser = "kate ~/.dotfiles/user/";
      ehome = "kate ~/.dotfiles/home.nix";
      ezsh  = "kate ~/.dotfiles/home/zsh.nix";

      # ── Tools ──────────────────────────────────────────────
      ftp      = "lftp";
      hex      = "xxd";
      b64e     = "base64";
      b64d     = "base64 -d";
      hashfile = "sha256sum";
      serve    = "python3 -m http.server";  # quick HTTP file server

      # ── SecLists explorer ──────────────────────────────────
      seclists = ''
        sh -c "
          SECLISTS_PATH=\"\''${SECLISTS_PATH:-/run/current-system/sw/share/wordlists/seclists/}\" &&
          printf \"=== Seclists Explorer ===\n\n%s\n\nThis is the Seclists wordlists directory (read-only in Nix store). Listing top-level folders:\n\n\" \"\$SECLISTS_PATH\" &&
          ls -la --group-directories-first \"\$SECLISTS_PATH\" 2>/dev/null | awk '/^d/ {print}'
        "
      '';
    };

    # ── Shell init content ───────────────────────────────────────────────────
    initContent = lib.mkMerge [
      # Key bindings at 1200 — after oh-my-zsh loads at 1100
      (lib.mkOrder 1200 ''
        bindkey "^[[1;5C" forward-word          # Ctrl+Right  jump word forward
        bindkey "^[[1;5D" backward-word         # Ctrl+Left   jump word back
        bindkey "^H"      backward-kill-word    # Ctrl+Bksp   delete word back
        bindkey "^[[3;5~" kill-word             # Ctrl+Del    delete word forward
        bindkey "^[[3~"   delete-char           # Delete      delete char forward
        bindkey "^[[H"    beginning-of-line     # Home
        bindkey "^[[F"    end-of-line           # End

        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        bindkey "^[[A" up-line-or-beginning-search    # Up   — history prefix search
        bindkey "^[[B" down-line-or-beginning-search  # Down — history prefix search

        # Expose last command char count to oh-my-posh via $OMP_CMD_LEN
        function _omp_track_cmd_len() { export OMP_CMD_LEN=''${#1}; }
        add-zsh-hook preexec _omp_track_cmd_len
      '')

      # Banner at 1500 — last thing printed before the first prompt
      (lib.mkAfter ''
        # ── AnNIXion banner ──────────────────────────────────────────────────
        echo ""
        echo "  \e[1;31m █████╗ ███╗   ██╗███╗  ██╗██╗██╗  ██╗██╗ ██████╗ ███╗ ██╗\e[0m"
        echo "  \e[1;31m██╔══██╗████╗  ██║████╗ ██║██║╚██╗██╔╝██║██╔═══██╗████╗██║\e[0m"
        echo "  \e[1;31m███████║██╔██╗ ██║██╔██╗██║██║ ╚███╔╝ ██║██║   ██║██╔████║\e[0m"
        echo "  \e[1;31m██╔══██║██║╚██╗██║██║╚████║██║ ██╔██╗ ██║██║   ██║██║╚███║\e[0m"
        echo "  \e[1;31m██║  ██║██║ ╚████║██║ ╚███║██║██╔╝╚██╗██║╚██████╔╝██║ ╚██║\e[0m"
        echo "  \e[1;31m╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚══╝╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝\e[0m"
        echo ""

        printf "  \e[0;90mhost  \e[0m %s\n" "$(hostname)"
        printf "  \e[0;90mdate  \e[0m %s\n" "$(date '+%A %d %B %Y  %H:%M')"
        printf "  \e[0;90mkernel\e[0m %s\n" "$(uname -r)"
        echo ""

        # Network interfaces — VPN interfaces highlighted in green
        ip -4 addr show scope global 2>/dev/null | awk '
          /inet/ {
            ip = $2
            split($NF, a, "@")
            iface = a[length(a)]
            if (iface ~ /^(tun|wg|vpn|ppp)/)
              printf "  \033[0;32mvpn   \033[0m \033[0;32m%-20s (%s) VPN\033[0m\n", ip, iface
            else
              printf "  \033[0;90mip    \033[0m %-20s (%s)\n", ip, iface
          }
        '
        echo ""
      '')
    ];
  };

  # ───────────────────────────────────────────────────────────────────────────
  # oh-my-posh — custom red-team prompt theme
  #
  # Layout:
  #   LEFT   [  user @ host ] [ path ] [ ⎇ branch ●+ ]
  #   RIGHT  [ Nc ] [ ⏱ 1m3s ] [ ✗ N ] [ 15:04:05 ]
  #   LINE2  ❯ (or #  when root)
  #
  # Right segments only appear when relevant (cmd length after first cmd,
  # exec time when > 3 s, exit code only on failure).
  # ───────────────────────────────────────────────────────────────────────────
  programs.oh-my-posh = {
    enable = true;

    settings = {
      "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
      version = 3;
      final_space = true;
      console_title_template = "{{ .Shell }} :: {{ .Folder }}";

      blocks = [
        # ── Line 1 — left ─────────────────────────────────────────────────
        {
          type = "prompt";
          alignment = "left";
          newline = true;
          segments = [
            # User @ Host — bright crimson bg, flips to vivid red when root
            {
              type = "session";
              style = "powerline";
              powerline_symbol = "";
              foreground = "#ffffff";
              background = "#8b0000";
              background_templates = [ "{{ if .Root }}#cc0000{{ end }}" ];
              template = "  {{ if .Root }}☠  ROOT{{ else }}{{ .UserName }}{{ end }}   {{ .HostName }}  ";
              properties.display_host = true;
            }
            # Path — light rose text on a slightly darker red
            {
              type = "path";
              style = "powerline";
              powerline_symbol = "";
              foreground = "#ffd0d0";
              background = "#4a0000";
              template = "   {{ .Path }}  ";
              properties = {
                style = "agnoster_short";
                max_depth = 4;
                home_icon = "~";
              };
            }
            # Git — amber on very dark red; shifts orange when dirty
            {
              type = "git";
              style = "powerline";
              powerline_symbol = "";
              foreground = "#ffb347";
              background = "#1e0000";
              foreground_templates = [
                "{{ if or .Working.Changed .Staging.Changed }}#ff7722{{ end }}"
              ];
              template = "   ⎇ {{ .HEAD }}{{ if .Staging.Changed }}  ●{{ end }}{{ if .Working.Changed }}  +{{ end }}  ";
              properties = {
                branch_icon = "";
                fetch_status = true;
              };
            }
          ];
        }

        # ── Line 1 — right ( cmdlen ◄ exectime ◄ exitcode ◄ clock ) ───────
        # Segments read right-to-left; the clock always anchors the far right.
        {
          type = "prompt";
          alignment = "right";
          segments = [
            # Clock — always visible, rose on dark red
            {
              type = "time";
              style = "powerline";
              powerline_symbol = "";
              foreground = "#ff9999";
              background = "#2d0000";
              template = ''  {{ .CurrentDate | date "15:04:05" }}  '';
            }
            # Exit code — only on failure, bright red on dark
            {
              type = "exit";
              style = "powerline";
              powerline_symbol = "";
              foreground = "#ff4444";
              background = "#1a0000";
              template = "  ✗ {{ .Code }}  ";
              properties.always_enabled = false;
            }
            # Execution time — only when last command took > 3 s
            {
              type = "executiontime";
              style = "powerline";
              powerline_symbol = "";
              foreground = "#ff9900";
              background = "#1a0000";
              template = "  ⏱ {{ .FormattedMs }}  ";
              properties = {
                threshold = 3000;
                style = "round";
                always_enabled = false;
              };
            }
            # Command char count — set by the preexec hook; hidden before first cmd
            {
              type = "text";
              style = "powerline";
              powerline_symbol = "";
              foreground = "#aa7777";
              background = "#0f0000";
              template = ''{{ if .Env.OMP_CMD_LEN }}  {{ .Env.OMP_CMD_LEN }}c  {{ end }}'';
            }
          ];
        }

        # ── Line 2 — prompt character ─────────────────────────────────────
        {
          type = "prompt";
          alignment = "left";
          newline = true;
          segments = [
            {
              type = "text";
              style = "plain";
              foreground = "#cc0000";
              foreground_templates = [ "{{ if .Root }}#ff4444{{ end }}" ];
              template = "{{ if .Root }}#  {{ else }}❯  {{ end }}";
            }
          ];
        }
      ];
    };
  };
}
