# VSCodium with the Nix toolchain: language server, formatter, linters.
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
        # ── Nix ─────────────────────────────────────────────────
        jnoortheen.nix-ide
        mkhl.direnv

        # ── General development ─────────────────────────────────
        eamodio.gitlens
        ms-vscode.makefile-tools
        tamasfe.even-better-toml
        redhat.vscode-yaml

        # ── CI/CD ───────────────────────────────────────────────
        github-local-actions # needs act + Docker
        timonwong.shellcheck
      ];
      userSettings = {
        # ── Nix IDE ─────────────────────────────────────────────
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "nix.linting.enabled" = true;

        # ── Editor ──────────────────────────────────────────────
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = true;
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
        };

        "editor.wordWrap" = "on";
        "editor.formatOnPaste" = true;
        "files.autoSave" = "afterDelay";
        "files.autoSaveDelay" = 1000;

        # ── Git ─────────────────────────────────────────────────
        "gitlens.hovers.currentLine.enabled" = true;
        "gitlens.codeLens.enabled" = true;

        # ── Terminal ────────────────────────────────────────────
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "terminal.integrated.fontFamily" = "monospace";

        # ── Tasks ───────────────────────────────────────────────
        "task.allowAutomaticTasks" = "on";
      };
    };
  };

  # ── Toolchain the extensions call out to ──────────────────────
  home.packages = with pkgs; [
    nix-your-shell
    nix-zsh-completions
    nixfmt
    statix
    deadnix
    nil
    act
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
