# home.nix — the operator user's environment.
# All mkDefault, so user/home.nix wins without lib.mkForce.
{
  lib,
  pkgs,
  ...
}:

let
  SlotIcons = pkgs.stdenvNoCC.mkDerivation {
    name = "Slot-Nord-Dark-Icons";
    src = pkgs.fetchFromGitHub {
      owner = "L4ki";
      repo = "Slot-Plasma-Themes";
      rev = "4dd93ad62cf47307d85e3a624eacba34578bf1fe";
      sha256 = "sha256-M2jCyPLPDqhF2KnovRIrsISOECpFgaR4TUI0N++P8ho=";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/icons
      cp -r "Slot Icons Themes/." $out/share/icons
    '';
  };

  TiledMenu = pkgs.stdenvNoCC.mkDerivation {
    pname = "plasma-applet-tiledmenu";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "Zren";
      repo = "plasma-applet-tiledmenu";
      rev = "master";
      hash = "sha256-noWH4bRyB/7v2K8jbj8ZD+5klUt4zOWiFZCEVdNmDL4=";
    };
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      dest=$out/share/plasma/plasmoids/com.github.zren.tiledmenu
      mkdir -p "$out/share/plasma/plasmoids"

      cp -rT ./package "$dest"

      if ! [ -f "$dest/metadata.json" ]; then
        echo "ERROR: metadata.json missing after install — source was empty or wrong layout" >&2
        exit 1
      fi
      runHook postInstall
    '';
  };

  AnNIXionIcons = import ./home/icons { inherit pkgs lib; };

  # Both themes have to land in one directory: xdg.dataFile."icons" owns the
  # whole path, so it cannot take two sources.
  IconSet = pkgs.symlinkJoin {
    name = "annixion-icon-set";
    paths = [
      "${SlotIcons}/share/icons"
      "${AnNIXionIcons}/share/icons"
    ];
  };
in
{
  imports = [
    ./home/firefox
    ./home/plasma.nix
    ./home/vscodium.nix
    ./home/only-office.nix
    ./home/apps-menu.nix
    ./home/control-center.nix
    ./home/fastfetch.nix
    ./home/zsh
    ./home/file-visibility.nix
    ./home/konsole.nix
    ./home/window-raise.nix
  ];

  home.username = lib.mkDefault "operator";
  home.homeDirectory = lib.mkDefault "/home/operator";

  # Like system.stateVersion — never change this.
  home.stateVersion = "26.05";

  programs.home-manager.enable = lib.mkDefault true;

  # Symlink so KDE picks the icon themes up.
  xdg.dataFile."icons".source = IconSet;

  # ── User packages ─────────────────────────────────────────
  # Offensive/OSINT/SDR tooling is system-wide, in modules/security-tools.nix.
  # The CLI the shell config leans on is system-wide, in modules/shell.nix,
  # so root's shell works the same as this one.
  home.packages = with pkgs; [
    # ── Development ───────────────────────────────────────────
    gh
    github-desktop
    python3Packages.pip

    # ── Utilities ─────────────────────────────────────────────
    unzip
    p7zip
    file
    wirelesstools
    net-tools
    dnsmasq
    wget
    htop
    tree
    act

    # ── Productivity ──────────────────────────────────────────
    obsidian
    kdePackages.kleopatra

    # ── Fonts ─────────────────────────────────────────────────
    kdePackages.fcitx5-qt

    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji

    # ── Icons & cursors ───────────────────────────────────────
    SlotIcons
    AnNIXionIcons
    nordzy-cursor-theme

    # ── Plasma widgets ────────────────────────────────────────
    TiledMenu

  ];

  services = {
    gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
      defaultCacheTtl = 1800;
      maxCacheTtl = 7200;
      enableSshSupport = true;
    };
  };

  home.activation.onlyofficeFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.local/share/fonts"

    cp -rf ${pkgs.noto-fonts}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true

    cp -rf ${pkgs.noto-fonts-cjk-sans}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true

    cp -rf ${pkgs.noto-fonts-cjk-serif}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true

    cp -rf ${pkgs.noto-fonts-color-emoji}/share/fonts/* \
      "$HOME/.local/share/fonts/" 2>/dev/null || true
  '';

  # ── TiledMenu install & configuration ─────────────────────
  # Plasma only scans ~/.local/share/plasma/plasmoids/ at session start.
  home.activation.installTiledMenu = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _tm="$HOME/.local/share/plasma/plasmoids/com.github.zren.tiledmenu"
    [ -d "$_tm" ] && $DRY_RUN_CMD chmod -R u+w "$_tm"
    $DRY_RUN_CMD rm -rf "$_tm"
    $DRY_RUN_CMD mkdir -p "$HOME/.local/share/plasma/plasmoids"
    $DRY_RUN_CMD cp -rL \
      "${TiledMenu}/share/plasma/plasmoids/com.github.zren.tiledmenu" \
      "$_tm"
    $DRY_RUN_CMD chmod -R u+w "$_tm"
  '';

  programs = {
    gpg = {
      enable = true;
    };
    # ── Git ─────────────────────────────────────────────────
    # Override userName/userEmail in user/home.nix (see user/examples/git.nix).
    git = {
      settings = {
        enable = lib.mkDefault true;
        userName = lib.mkDefault "CHANGEME";
        userEmail = lib.mkDefault "your@email.com";
        extraConfig = lib.mkDefault {
          init.defaultBranch = "main";
          pull.rebase = false;
        };
      };
    };
  };
}
