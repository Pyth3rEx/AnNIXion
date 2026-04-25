# home.nix
# This file declares everything about YOUR user environment.
# Think of it as your personal layer on top of the system.
# Changes here only affect the "operator" user, not the whole system.
{ config, pkgs, ... }:

{
  # Home Manager needs to know your username and home directory.
  home.username = "operator";
  home.homeDirectory = "/home/operator";

  # Like system.stateVersion — do not change this.
  home.stateVersion = "26.05";

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  # ============================================================
  # USER PACKAGES
  # ============================================================
  # These are installed only for your user, not system-wide.
  # Security tools, personal apps, CLI utilities go here.
  home.packages = with pkgs; [
    # ── Terminal & Shell ──────────────────────────────────────
    kitty          # fast GPU-accelerated terminal
    tmux           # terminal multiplexer (multiple panes/sessions)
    zsh            # better shell than bash

    # ── Offensive Security ────────────────────────────────────
    nmap           # network scanner
    netcat-gnu     # networking swiss army knife
    wireshark      # packet capture & analysis
    burpsuite      # web app pentesting proxy
    metasploit     # exploitation framework
    sqlmap         # SQL injection tool
    gobuster       # directory/DNS brute forcer
    ffuf           # fast web fuzzer
    john           # password cracker
    hashcat        # GPU password cracker
    hydra          # network login brute forcer
    aircrack-ng    # WiFi security auditing
    binwalk        # firmware analysis
    ghidra         # reverse engineering / disassembler

    # ── OSINT ─────────────────────────────────────────────────
    theharvester   # email/domain/IP OSINT
    whois
    dnsutils       # dig, nslookup

    # ── SDR / RF (your HackRF etc.) ───────────────────────────
    hackrf         # HackRF tools
    gqrx           # SDR receiver GUI
    gnuradio       # SDR signal processing

    # ── Development ───────────────────────────────────────────
    vscode
    gh             # GitHub CLI
    python3
    python3Packages.pip

    # ── Utilities ─────────────────────────────────────────────
    ripgrep        # fast grep (rg)
    fd             # fast find
    bat            # cat with syntax highlighting
    fzf            # fuzzy finder
    jq             # JSON processor
    unzip
    p7zip

    # ── Fonts ─────────────────────────────────────────────────
    nerd-fonts.jetbrains-mono  # terminal font with icons
    nerd-fonts.fira-code
  ];

  # ============================================================
  # SHELL — ZSH
  # ============================================================
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # suggests commands as you type
    syntaxHighlighting.enable = true;  # colors valid/invalid commands
    enableCompletion = true;

    # Your shell aliases
    shellAliases = {
      ll = "ls -la";
      gs = "git status";
      gp = "git push";
      gl = "git pull";
      rebuild = "sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion";
      # Quick edit of your configs
      enix = "kate ~/.dotfiles/configuration.nix";
      ehome = "kate ~/.dotfiles/home.nix";
    };

    # Extra config appended to .zshrc
    initContent = ''
      # Use fzf for ctrl+r history search
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
    '';
  };

  # Set zsh as default shell
  home.sessionVariables = {
    SHELL = "${pkgs.zsh}/bin/zsh";
  };

  # ============================================================
  # TERMINAL — KITTY
  # ============================================================
  programs.kitty = {
    enable = true;
    settings = {
      # Dark theme
      background = "#0d0d0d";
      foreground = "#e0e0e0";
      cursor = "#e0e0e0";

      # Font
      font_family = "JetBrainsMono Nerd Font";
      font_size = 12;

      # Behavior
      copy_on_select = true;   # auto-copy on mouse select
      strip_trailing_spaces = "smart";

      # Window
      window_padding_width = 8;
      hide_window_decorations = "yes";
    };
  };

  # ============================================================
  # GIT
  # ============================================================
  programs.git = {
    enable = true;
    userName = "Pyth3rEx";
    userEmail = "your@email.com"; # replace this
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # ============================================================
  # TMUX
  # ============================================================
  programs.tmux = {
    enable = true;
    shortcut = "a";        # Ctrl+a prefix instead of Ctrl+b
    baseIndex = 1;         # windows start at 1 not 0
    escapeTime = 0;        # no delay on Escape key
    historyLimit = 50000;
    terminal = "screen-256color";

    extraConfig = ''
      # Split panes with | and -
      bind | split-window -h
      bind - split-window -v

      # Switch panes with Alt+arrow (no prefix needed)
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

      # Status bar
      set -g status-style 'bg=#1a1a1a fg=#e0e0e0'
      set -g status-left '#[fg=#ff5555,bold] AnNIXion #[fg=#e0e0e0]| '
      set -g status-right '#[fg=#888888]%H:%M %d-%b-%Y'
    '';
  };

  # ============================================================
  # KDE / KWIN SETTINGS (Krohnkite tiling + shortcuts)
  # ============================================================
  # These write directly into KDE's config files in ~/.config/
  # plasma-manager handles the translation to KDE format.

  programs.plasma = {
    enable = true;

    # ── Global shortcuts ──────────────────────────────────────
    shortcuts = {
      # KRunner — your app launcher (like wofi/rofi)
      "org.kde.krunner.desktop"."_launch" = [ "Alt+Space" "Alt+F2" ];

      # KWin window management
      kwin = {
        # Virtual desktops — switch with Meta+number
        "Switch to Desktop 1" = "Meta+1";
        "Switch to Desktop 2" = "Meta+2";
        "Switch to Desktop 3" = "Meta+3";
        "Switch to Desktop 4" = "Meta+4";

        # Move window to desktop
        "Window to Desktop 1" = "Meta+Shift+1";
        "Window to Desktop 2" = "Meta+Shift+2";
        "Window to Desktop 3" = "Meta+Shift+3";
        "Window to Desktop 4" = "Meta+Shift+4";

        # Window controls
        "Window Maximize" = "Meta+Up";
        "Window Minimize" = "Meta+Down";
        "Window Close" = "Meta+Q";
        "Window Fullscreen" = "Meta+F";

        # Focus switching (Krohnkite uses these)
        "Switch Window Up" = "Meta+Shift+Up";
        "Switch Window Down" = "Meta+Shift+Down";
        "Switch Window Left" = "Meta+Shift+Left";
        "Switch Window Right" = "Meta+Shift+Right";
      };

      # Launch terminal with Meta+Return (like i3/Hyprland)
      "org.kde.konsole.desktop"."NewWindow" = "Meta+Return";
    };

    # ── KWin config (Krohnkite tiling script) ─────────────────
    configFile = {
      # Enable Krohnkite tiling script
      "kwinrc"."Plugins"."krohnkiteEnabled" = true;

      # Virtual desktops — 4 desktops like a proper tiling setup
      "kwinrc"."Desktops"."Number" = 4;
      "kwinrc"."Desktops"."Rows" = 1;

      # Window behavior
      "kwinrc"."Windows"."FocusPolicy" = "FocusFollowsMouse";
      "kwinrc"."Windows"."FocusStealingPreventionLevel" = 1;

      # Compositor — keep effects minimal for VM performance
      "kwinrc"."Compositing"."AnimationSpeed" = 3;
      "kwinrc"."Compositing"."Enabled" = true;

      # Dark theme
      "kdeglobals"."General"."ColorScheme" = "BreezeDark";
      "kdeglobals"."KDE"."LookAndFeelPackage" = "org.kde.breezedark.desktop";
    };

    # ── Krohnkite tiling config ───────────────────────────────
    # Krohnkite is configured via its own config file
    dataFile = {
      "krohnkite/krohnkiterc" = {
        # Default layout: Tall (master + stack, like i3 default)
        "layoutOrder" = "0,3";   # 0=Tall, 3=Monocle

        # Gaps between windows (pixels)
        "screenGapTop" = 8;
        "screenGapBottom" = 8;
        "screenGapLeft" = 8;
        "screenGapRight" = 8;
        "tileLayoutGap" = 8;

        # Master area takes 55% of screen
        "masterRatio" = 0.55;

        # Float these window types (popups, dialogs etc.)
        "floatingClass" = "plasmashell,krunner,kded5";
      };
    };
  };

  # ============================================================
  # FONTS
  # ============================================================
  fonts.fontconfig.enable = true;
}
