{ config, pkgs, ... }:

let
  github-local-actions = pkgs.vscode-utils.buildVscodeExtension {
    pname = "SanjulaGanepola-github-local-actions";
    version = "1.2.5";
    src = pkgs.fetchurl {
      url = "https://open-vsx.org/api/SanjulaGanepola/github-local-actions/1.2.5/file/SanjulaGanepola.github-local-actions-1.2.5.vsix";
      sha256 = "1dqqpzi749mqn983b6m3k90biyn4xfj2d8y9jy1fc9039is0bhrz";
    };
    vscodeExtPublisher = "SanjulaGanepola";
    vscodeExtName = "github-local-actions";
    vscodeExtUniqueId = "SanjulaGanepola.github-local-actions";
  };
in
{
  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium;

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

        # CI/CD tools
        github-local-actions  # run GitHub Actions workflows locally (requires act + Docker)
        timonwong.shellcheck
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

        # Task runner
        "task.allowAutomaticTasks" = "on";
      };
    };
  };

  # Development environment dependencies
  home.packages = with pkgs; [
    # Nix tooling
    nix-your-shell
    nix-zsh-completions
    nixfmt
    statix
    deadnix

    # Language servers
    nil

    # Local GitHub Actions runner (used by github-local-actions extension)
    act
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
