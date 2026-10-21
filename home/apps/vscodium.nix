# VSCodium with the Nix toolchain: language server, formatter, linters.
{ pkgs, ... }:

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
    # No DRM render node on a Hyper-V guest, so Chromium falls back to
    # SwiftShader's software GL, whose worker pool burns 150-300% of a core
    # whenever anything renders (#166). --disable-gpu takes the CPU raster
    # path instead.
    package = pkgs.vscodium.override { commandLineArgs = "--disable-gpu"; };
    mutableExtensionsDir = false;

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

        # ── Shell ───────────────────────────────────────────────
        mads-hartmann.bash-ide-vscode
        timonwong.shellcheck

        # ── C/C++ development ───────────────────────────────────
        llvm-vs-code-extensions.vscode-clangd
        vadimcn.vscode-lldb
        ms-vscode.cmake-tools
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

        # ── C/C++ ───────────────────────────────────────────────
        "clangd.path" = "${pkgs.clang-tools}/bin/clangd";
        "clangd.arguments" = [
          "--clang-tidy"
          "--header-insertion=iwyu"
        ];
        "lldb.executable" = "${pkgs.lldb}/bin/lldb";
        "[c]" = {
          "editor.defaultFormatter" = "llvm-vs-code-extensions.vscode-clangd";
          "editor.formatOnSave" = true;
        };
        "[cpp]" = {
          "editor.defaultFormatter" = "llvm-vs-code-extensions.vscode-clangd";
          "editor.formatOnSave" = true;
        };

        # ── Shell ───────────────────────────────────────────────
        # Cleared, not unset: nixpkgs patches the server's shellcheck path to
        # the store, which would report every finding timonwong.shellcheck
        # already reports.
        "bashIde.shellcheckPath" = "";
        "bashIde.shfmt.caseIndent" = true;
        # shfmt reads its indent from the editor; repo scripts are -i 2 -ci.
        "[shellscript]" = {
          "editor.defaultFormatter" = "mads-hartmann.bash-ide-vscode";
          "editor.formatOnSave" = true;
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
        };

        # ── Files ───────────────────────────────────────────────
        # The explorer's default exclude list hides .git and friends, which
        # is the one place dotfiles stayed invisible after the desktop-wide
        # switches in home/desktop/file-visibility.nix (#162). Empty, not
        # absent: an unset value falls back to that default list.
        "files.exclude" = { };

        "editor.wordWrap" = "on";
        "editor.formatOnPaste" = true;
        "files.autoSave" = "afterDelay";
        "files.autoSaveDelay" = 1000;

        # ── Git ─────────────────────────────────────────────────
        "gitlens.hovers.currentLine.enabled" = true;
        "gitlens.codeLens.enabled" = true;

        # ── Keyboard ────────────────────────────────────────────
        # Dispatching on scan codes assumes the OS reports them correctly.
        # Hyper-V Enhanced Session does not, so AltGr arrives as a bare
        # cursor-left (#163, microsoft/vscode#24783). keyCode reads the
        # layout instead, which AZERTY composition needs.
        "keyboard.dispatch" = "keyCode";

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
