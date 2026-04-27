# home.nix
# This file declares everything about YOUR user environment.
# Think of it as your personal layer on top of the system.
# Changes here only affect the "operator" user, not the whole system.
#
# Every option uses lib.mkDefault (priority 1000). That means anything
# you put in user/home.nix at normal priority (100) automatically wins
# without needing lib.mkForce.
{ config, lib, pkgs, ... }:

{
  # Home Manager needs to know your username and home directory.
  home.username = lib.mkDefault "operator";
  home.homeDirectory = lib.mkDefault "/home/operator";

  # Like system.stateVersion — do not change this ever.
  # It records the Home Manager version you first activated with.
  home.stateVersion = "25.11";

  # Let Home Manager manage itself.
  programs.home-manager.enable = lib.mkDefault true;

  # ============================================================
  # USER PACKAGES
  # ============================================================
  # These are installed only for the operator user, not system-wide.
  # Offensive/OSINT/SDR tools have moved to modules/security-tools.nix
  # and are now system-wide packages.
  home.packages = with pkgs; [
    # ── Terminal & Shell ──────────────────────────────────────
    tmux           # terminal multiplexer (multiple panes/sessions)
    zsh            # better shell than bash

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
    enable = lib.mkDefault true;
    autosuggestion.enable = lib.mkDefault true;      # suggests commands as you type
    syntaxHighlighting.enable = lib.mkDefault true;  # colors valid/invalid commands
    enableCompletion = lib.mkDefault true;

    # Your shell aliases
    shellAliases = lib.mkDefault {
      ll = "ls -la";
      gs = "git status";
      gp = "git push";
      gl = "git pull";
      rebuild = "sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion";
      # Quick edit of your configs
      enix  = "kate ~/.dotfiles/flake.nix";
      emod  = "kate ~/.dotfiles/modules/";
      euser = "kate ~/.dotfiles/user/";
      ehome = "kate ~/.dotfiles/home.nix";
    };

    # Extra config appended to .zshrc
    initContent = lib.mkDefault ''
      # Auto-launch tmux when opening a terminal (but not inside tmux already)
      if [ -z "$TMUX" ]; then
        exec tmux new-session -A -s main
      fi

      # Use fzf for ctrl+r history search
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
    '';
  };

  # Set zsh as default shell
  home.sessionVariables = lib.mkDefault {
    SHELL = "${pkgs.zsh}/bin/zsh";
  };

  # ============================================================
  # GIT
  # ============================================================
  programs.git = {
    enable = lib.mkDefault true;
    userName = lib.mkDefault "CHANGME";
    userEmail = lib.mkDefault "your@email.com";
    extraConfig = lib.mkDefault {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # ============================================================
  # TMUX
  # ============================================================
  programs.tmux = {
    enable = lib.mkDefault true;
    # shortcut = "a";        # Ctrl+a prefix instead of Ctrl+b
    baseIndex = lib.mkDefault 1;         # windows start at 1 not 0
    escapeTime = lib.mkDefault 0;        # no delay on Escape key
    historyLimit = lib.mkDefault 50000;
    terminal = lib.mkDefault "screen-256color";

    extraConfig = lib.mkDefault ''
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
    enable = lib.mkDefault true;

    # ── Global shortcuts ──────────────────────────────────────
    shortcuts = lib.mkDefault {
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

      # Launch terminal with Meta+Return — tmux in xterm
      "org.kde.kglobalaccel.desktop"."run command" = "Meta+Return";
    };

    # ── KWin config (Krohnkite tiling script) ─────────────────
    configFile = lib.mkDefault {
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

      # Krohnkite tiling settings
      "kwinrc"."Script-krohnkite"."enableTileLayout" = true;
      "kwinrc"."Script-krohnkite"."screenGapTop" = 8;
      "kwinrc"."Script-krohnkite"."screenGapBottom" = 8;
      "kwinrc"."Script-krohnkite"."screenGapLeft" = 8;
      "kwinrc"."Script-krohnkite"."screenGapRight" = 8;
      "kwinrc"."Script-krohnkite"."tileLayoutGap" = 8;
      "kwinrc"."Script-krohnkite"."masterRatio" = "0.55";
    };
  };

  # ============================================================
  # FONTS
  # ============================================================
  fonts.fontconfig.enable = lib.mkDefault true;
}