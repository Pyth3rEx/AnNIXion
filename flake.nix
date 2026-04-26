# flake.nix
{
  description = "Main AnNIXion flake";

  inputs = {
    # Main nixpkgs — your system packages come from here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Home Manager — declares your user environment (dotfiles,
    # shortcuts, apps) in Nix. Follows the same nixpkgs version.
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # plasma-manager — lets you declare KDE Plasma settings in Nix.
    # Without this, programs.plasma doesn't exist in Home Manager.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, ... }:
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations = {
      AnNIXion = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hardware-configuration.nix

          # ── Feature modules ──────────────────────────────────
          ./modules/desktop.nix
          ./modules/xrdp.nix
          ./modules/shell.nix
          ./modules/security-tools.nix

          # ── Wire Home Manager into the NixOS build ───────────
          # "nixos-rebuild switch" handles both system AND user config
          # in one command — no separate "home-manager switch" step needed.
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;   # share system pkgs
            home-manager.useUserPackages = true;  # install to user profile
            # Give Home Manager access to the plasma-manager module
            home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];

            # Merge home.nix with user/home.nix (if it exists).
            # home.nix uses lib.mkDefault throughout (priority 1000).
            # user/home.nix uses normal priority (100) and therefore wins
            # automatically — no lib.mkForce needed in your overrides.
            home-manager.users.operator = { imports =
              [ ./home.nix ] ++
              (if builtins.pathExists ./user/home.nix then [ ./user/home.nix ] else []);
            };
          }

          # ── Core system configuration ────────────────────────
          # Boot, networking, nix settings, locale, audio, user account,
          # base system packages, SSH. All options use lib.mkDefault so
          # user/configuration.nix can override any of them freely.
          ({ config, lib, pkgs, ... }: {

            # ============================================================
            # BOOT LOADER
            # ============================================================
            boot.loader.systemd-boot.enable = lib.mkDefault true;
            boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

            # ============================================================
            # NETWORKING
            # ============================================================
            networking.hostName = lib.mkDefault "AnNIXion";
            networking.networkmanager.enable = lib.mkDefault true;

            # ============================================================
            # NIX SETTINGS
            # ============================================================
            # Enable modern nix commands (nix run, nix build, nix flake etc.)
            nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];

            # Auto-delete old system generations older than 15 days.
            # NixOS keeps every old version for rollback — this prevents
            # your disk filling up over time.
            nix.gc = {
              automatic = lib.mkDefault true;
              dates     = lib.mkDefault "weekly";
              options   = lib.mkDefault "--delete-older-than 15d";
            };

            # ============================================================
            # LOCALE & TIME
            # ============================================================
            time.timeZone      = lib.mkDefault "Europe/Paris";
            i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

            # ============================================================
            # AUDIO (Pipewire)
            # ============================================================
            # Enhanced Session passes audio from the VM to Windows.
            services.pipewire = {
              enable            = lib.mkDefault true;
              alsa.enable       = lib.mkDefault true;
              alsa.support32Bit = lib.mkDefault true;
              pulse.enable      = lib.mkDefault true;
            };

            # ============================================================
            # SECURITY & SUDO
            # ============================================================
            # Allow users in the "wheel" group to use sudo.
            security.sudo.wheelNeedsPassword = lib.mkDefault true;

            # ============================================================
            # USER ACCOUNT
            # ============================================================
            users.users.operator = {
              isNormalUser = lib.mkDefault true;
              extraGroups  = lib.mkDefault [
                "wheel"          # sudo access
                "networkmanager" # manage network connections
                "video"          # needed for some hardware tools
                "input"          # needed for input devices
              ];
              hashedPassword = lib.mkDefault "$6$DkRVwYEQPe/aYDUp$ULU/oBw9ujsQa5.s4EgWKL2YNNZ2SmEfA0PrMqF6XrZ.FCOsplXdTTEPsWmFH1dU0tB0/JRHeSxasjPBBuQAu1";
            };

            # ============================================================
            # SYSTEM PACKAGES
            # ============================================================
            # Core utilities installed system-wide, available to all users.
            # Tool-specific packages live in the relevant module.
            nixpkgs.config.allowUnfree = lib.mkDefault true;

            environment.systemPackages = with pkgs; [
              git
              wget
              curl
              htop
              tree
              networkmanager
            ];

            # ============================================================
            # SSH — useful fallback if xrdp has issues
            # ============================================================
            services.openssh = {
              enable                      = lib.mkDefault true;
              settings.PasswordAuthentication = lib.mkDefault true;
            };

            # ============================================================
            # STATE VERSION — do not change this ever
            # ============================================================
            # This is the NixOS version you first installed with.
            # It controls stateful defaults. Changing it breaks things.
            # lib.mkDefault is used so a conflict error is avoided if you
            # accidentally set it in user/configuration.nix — but don't.
            system.stateVersion = lib.mkDefault "26.05";

          })

        # ── User overrides (system level) ────────────────────────────
        # user/configuration.nix is imported only if the file exists.
        # Because all base options above use lib.mkDefault (priority 1000),
        # anything you write in that file at normal priority (100) wins
        # automatically — no lib.mkForce needed.
        ] ++ (if builtins.pathExists ./user/configuration.nix
              then [ ./user/configuration.nix ]
              else []);
      };
    };
  };
}