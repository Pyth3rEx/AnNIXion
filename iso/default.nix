# Live installer ISO: auto-login shell with annixion-install on PATH.
{ lib, pkgs, ... }:
let
  version = lib.removeSuffix "\n" (builtins.readFile ../VERSION);
  branding = import ../branding { inherit pkgs; };

  # The installer script plus the wizard/validation/nixpkgs-pin libraries
  # it sources — bin/ and libexec/ side by side, so scripts/annixion-install's
  # own relative lookup finds them the same way it does from a checkout.
  installScript = pkgs.runCommand "annixion-install" { } ''
    mkdir -p $out/bin $out/libexec/annixion-installer
    install -m755 ${../scripts/annixion-install} $out/bin/annixion-install
    install -m644 ${../scripts/installer/validate.sh} $out/libexec/annixion-installer/validate.sh
    install -m644 ${../scripts/installer/wizard.sh} $out/libexec/annixion-installer/wizard.sh
    install -m644 ${../scripts/installer/nixpkgs-pin.sh} $out/libexec/annixion-installer/nixpkgs-pin.sh
  '';
in
{
  # ── ISO image metadata ──────────────────────────────────────────────────
  image = {
    baseName = lib.mkForce "AnNIXion";
    fileName = lib.mkForce "AnNIXion-${version}.iso";
  };
  # The boot menu label is "${prependToMenuLabel}${distroName} ${label}
  # ${appendToMenuLabel}" — left at its defaults this reads "NixOS 25.11
  # Installer", not AnNIXion at all.
  system.nixos = {
    distroName = "AnNIXion";
    label = "v${version}";
  };
  isoImage = {
    volumeID = lib.mkForce "ANNIXION";
    squashfsCompression = "xz -Xdict-size 100%";
    appendToMenuLabel = " installer";

    # syslinux draws the BIOS menu over the first, GRUB the EFI one. Both
    # default to NixOS artwork fetched from GitHub, so overriding them also
    # drops two fetchurls from the ISO's evaluation.
    splashImage = lib.mkForce branding.isoSplashBios;
    efiSplashImage = lib.mkForce branding.isoSplashEfi;

    # Whenever a grub theme is set (the default — pkgs.nixos-grub2-theme —
    # counts), GRUB's gfxmenu takes over the EFI boot screen and
    # efiSplashImage above is never drawn. This is what actually themes it.
    grubTheme = lib.mkForce branding.grubTheme;

    # nixpkgs' default syslinux theme sets MENU COLOR UNSEL to black text on
    # a transparent background, which is fine over the upstream NixOS splash
    # but invisible over ours (black on black) — only the SEL entry, drawn
    # with an opaque highlight, shows up until it's moved off.
    syslinuxTheme = lib.mkForce ''
      MENU TITLE AnNIXion
      MENU RESOLUTION 800 600
      MENU CLEAR
      MENU ROWS 6
      MENU CMDLINEROW -4
      MENU TIMEOUTROW -3
      MENU TABMSGROW  -2
      MENU HELPMSGROW -1
      MENU HELPMSGENDROW -1
      MENU MARGIN 0

      #                                FG:AARRGGBB  BG:AARRGGBB   shadow
      MENU COLOR BORDER       30;44      #00000000    #00000000   none
      MENU COLOR SCREEN       37;40      #FFE6E6E6    #FF000000   none
      MENU COLOR TABMSG       31;40      #80FFFFFF    #00000000   none
      MENU COLOR TIMEOUT      1;37;40    #FFE6E6E6    #00000000   none
      MENU COLOR TIMEOUT_MSG  37;40      #FFE6E6E6    #00000000   none
      MENU COLOR CMDMARK      1;36;40    #FFE6E6E6    #00000000   none
      MENU COLOR CMDLINE      37;40      #FFE6E6E6    #00000000   none
      MENU COLOR TITLE        1;36;44    #FFE6E6E6    #00000000   none
      MENU COLOR UNSEL        37;44      #FFE6E6E6    #00000000   none
      MENU COLOR SEL          7;37;40    #FF0B0B0D    #FFFF0033   std
    '';
  };

  # Lets the installer's libexec/ scripts (installer/validate.sh,
  # installer/wizard.sh, installer/nixpkgs-pin.sh) land in
  # /run/current-system/sw/libexec, beside sw/bin
  # — otherwise systemPackages only links /bin, and the layout installScript
  # builds in bin/ + libexec/ never reaches $PATH's view of the world.
  environment.pathsToLink = [ "/libexec" ];

  # systemd's get_keymaps() (what `localectl list-keymaps` calls — the
  # wizard's keyboard-layout step) only ever scans /usr/share/keymaps,
  # /usr/share/kbd/keymaps and /usr/lib/kbd/keymaps — all FHS paths NixOS
  # doesn't have, pathsToLink or no — unless this is set, in which case it
  # takes over as the sole search path. No amount of linking kbd into
  # /run/current-system/sw changes what systemd actually looks at.
  environment.variables.SYSTEMD_KEYMAP_DIRECTORIES = "${pkgs.kbd}/share/keymaps";

  boot = {
    # The new default from 26.11; the live image never imports a root pool it
    # did not create.
    zfs.forceImportRoot = false;

    # The live image is a console session, so the splash is the only place the
    # mark appears between the boot menu and the installer prompt.
    plymouth = {
      enable = true;
      themePackages = [ branding.plymouthTheme ];
      theme = "annixion";
    };
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
    ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.hostName = lib.mkDefault "AnNIXion";
  networking.networkmanager.enable = lib.mkDefault true;
  # Belt-and-suspenders for networks where DHCP hands out connectivity but a
  # DNS server that doesn't actually resolve (common on the kind of networks
  # a live installer gets booted on) — resolvconf appends these alongside
  # whatever DHCP provides, so a working upstream DHCP DNS is untouched.
  # Quad9, not Google/Cloudflare — no query logging, matches how the rest
  # of AnNIXion treats DNS.
  networking.nameservers = [
    "9.9.9.9"
    "149.112.112.112"
  ];

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # ── Live user — auto‑login to shell ────────────────────────────────────
  users.users.operator = {
    isNormalUser = true;
    password = "operator";
    # Not the system default zsh: a brand-new $HOME with no .zshrc/.zshenv
    # makes zsh run its own first-time setup wizard (zsh-newuser-install)
    # before anything else, on every single boot — this account never gets
    # a persistent home to save one in, and it's exactly what "zshell
    # prompting the user" during the TUI launch turned out to be. bash has
    # no equivalent; operator has no reason to be in zsh here anyway.
    shell = pkgs.bash;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
  };
  services.getty.autologinUser = lib.mkForce "operator";

  # Allow password‑less sudo for the installer
  security.sudo.wheelNeedsPassword = lib.mkForce false;
  security.sudo.extraConfig = ''
    # The operator may run the installer as root without a password.
    operator ALL=(ALL) NOPASSWD: ${installScript}/bin/annixion-install
    # sudo's env_reset default strips SYSTEMD_KEYMAP_DIRECTORIES along with
    # everything else operator's shell set — annixion-install re-execs
    # itself through sudo before the wizard's `localectl list-keymaps`
    # ever runs, so without this it's back to "Failed to read list of
    # keymaps" as root, despite the variable being set and correct one
    # process up.
    Defaults:operator env_keep += "SYSTEMD_KEYMAP_DIRECTORIES"
  '';

  # ── Launch the installer ────────────────────────────────────────────────
  # tty1 is the only console the live ISO puts in front of a user, so it
  # drops straight into the TUI instead of leaving them at a bare shell to
  # go find annixion-install themselves. No text printed first — anything
  # echoed here would flash on the raw terminal for an instant before
  # annixion-install takes the alt screen, reading as a stray shell prompt
  # rather than an app starting; the welcome and nmtui hint live in its own
  # banner now. Not execd: a finished or aborted run (e.g. no network yet)
  # falls back to this same shell for nmtui, retries.
  users.users.operator.packages = [ pkgs.figlet ];
  environment.interactiveShellInit = ''
    # nmtui doesn't reliably hand the console back the way it found it on
    # this console — colours and local echo can both still be off after it
    # exits, until some later command happens to reset them. Do that
    # ourselves rather than leave the shell looking broken in the meantime.
    nmtui() {
      command nmtui "$@"
      stty sane 2>/dev/null
      tput sgr0 2>/dev/null
      clear
    }

    if [ "$(tty)" = "/dev/tty1" ]; then
      annixion-install || true
    fi
  '';

  # ── Packages available in the live session ─────────────────────────────
  environment.systemPackages = with pkgs; [
    installScript
    git
    parted
    dosfstools # mkfs.fat
    e2fsprogs # mkfs.ext4
    cryptsetup # LUKS2 full-disk encryption
    networkmanager
    networkmanagerapplet
    pciutils
    usbutils
    wget
    curl # queries GitHub's API for installer/nixpkgs-pin.sh's cooldown resolution
    vim
    gum # the installer wizard's TUI
    mkpasswd # hashes the account password the wizard collects
    jq # parses `nix eval --json`/GitHub API JSON in installer/validate.sh and installer/nixpkgs-pin.sh
    # Mints the sysreptor login hash — hashlib/secrets/base64/string are all
    # stdlib, so the bare interpreter is enough (installer/wizard.sh).
    python3
  ];

  system.stateVersion = "26.05";
}
