{ config, pkgs, ... }:

{
  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium; # Using VSCodium (open-source) or use pkgs.vscode for proprietary version

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # Nix Language Support
        jnoortheen.nix-ide

        # Additional useful extensions for Nix development
        mkhl.direnv

        # General development tools
        eamodio.gitlens
        ms-vscode.makefile-tools
        tamasfe.even-better-toml
        redhat.vscode-yaml
      ];
      userSettings = {
        # Nix IDE Configuration
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "nix.linting.enabled" = true;

        # Editor settings
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = true;
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
        };

        # General VS Code settings
        "editor.wordWrap" = "on";
        "editor.formatOnPaste" = true;
        "files.autoSave" = "afterDelay";
        "files.autoSaveDelay" = 1000;

        # Git settings
        "gitlens.hovers.currentLine.enabled" = true;
        "gitlens.codeLens.enabled" = true;

        # Terminal settings
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "terminal.integrated.fontFamily" = "monospace";
      };
    };
  };

  # Development environment dependencies
  home.packages = with pkgs; [
    # Nix tooling
    nix-your-shell
    nix-zsh-completions
    nixfmt
    statix # Linter for Nix
    deadnix # Find unused code in Nix files

    # Language servers
    nil # Nix language server (used by nix-ide)

  ];

  # Optional: Add direnv integration for automatic environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
