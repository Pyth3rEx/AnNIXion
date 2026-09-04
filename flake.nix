# Flake entry point: inputs, system/user wiring, checks and dev shell.
{
  description = "Main AnNIXion flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      plasma-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgsUnfree = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Everything bar the machine's disk layout. Shared by the real system
      # and the CI stand-in so the two cannot drift apart.
      baseModules = [
        # ── Feature modules ──────────────────────────────────
        ./system/desktop.nix
        ./system/branding.nix
        ./system/xrdp.nix
        ./system/security-tools.nix
        ./system/burp-ca.nix
        ./system/vpn
        ./system/hardening.nix
        ./system/shell.nix
        ./system/git.nix
        ./system/docker.nix

        # Only the HM-wrapped Firefox carries policies.json (CA trust,
        # extensions); bare pkgs.firefox drops them silently.
        (
          { config, ... }:
          {
            annixion.vpnEnforcement.browserPackage =
              config.home-manager.users.operator.programs.firefox.finalPackage;
          }
        )

        # ── Home Manager ─────────────────────────────────────
        # "nixos-rebuild switch" then covers system and user config.
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            # HM aborts on a file it did not create; back it up instead.
            backupFileExtension = "backup";
            sharedModules = [ plasma-manager.homeModules.plasma-manager ];
            extraSpecialArgs = { inherit inputs; };

            users.operator = {
              imports = [
                ./home
              ]
              ++ (if builtins.pathExists ./user/home.nix then [ ./user/home.nix ] else [ ]);
            };

            # Root gets the same shell as the operator — prompt, aliases,
            # plugins, keybindings, banner — but none of the desktop half of
            # home.nix. Cheaper than mirroring the config into NixOS options,
            # and the two cannot drift.
            users.root = {
              imports = [ ./home/shell ];
              home.stateVersion = "26.05";
            };
          };
        }

        # ── Core system configuration ────────────────────────
        # All mkDefault, so user/configuration.nix overrides freely.
        ./system/core/boot.nix
        ./system/core/os-release.nix
        ./system/core/networking.nix
        ./system/core/nix.nix
        ./system/core/locale.nix
        ./system/core/audio.nix
        ./system/core/security.nix
        ./system/core/users.nix
        ./system/core/packages.nix
        ./system/core/state-version.nix
      ]
      # ── User overrides (system level) ────────────────────────────
      ++ (if builtins.pathExists ./user/configuration.nix then [ ./user/configuration.nix ] else [ ]);

      # The disk layout is the only thing that varies between a real install
      # and CI.
      mkAnnixion =
        hardwareModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ hardwareModule ] ++ baseModules;
        };
    in
    {
      packages.${system} = {
        iso = self.nixosConfigurations.AnNIXion-iso.config.system.build.isoImage;
        # tests/shell/branding.sh builds the greeter through here rather than from
        # <nixpkgs>, which a CI runner does not set.
        sddm-theme = (import ./branding { inherit pkgs; }).sddmTheme;

        # The catalog as plain data, for the same reason: tests/catalog.sh
        # reads it through here rather than importing it against <nixpkgs>.
        # Only what a test can assert about — no drawings, no functions.
        catalog-json =
          let
            inherit (pkgs) lib;
            c = import ./catalog { inherit lib; };
            node = n: {
              inherit (n) path order directory;
              category = n.category or null;
              mark = n.mark.name;
              tools = builtins.attrNames n.tools;
              children = map (x: x.path) n.children;
            };
          in
          pkgs.writeText "annixion-catalog.json" (
            builtins.toJSON {
              nodes = map node c.allNodes;
              tools = lib.mapAttrs (_: t: {
                inherit (t) path category launch;
                hasPackage = (t.package or null) != null;
                alsoIn = t.alsoIn or [ ];
                wmName = t.wmName or null;
              }) c.tools;
              marks = builtins.attrNames c.marks;
              support = builtins.attrNames c.support;
            }
          );
      };

      nixosConfigurations = {
        AnNIXion-iso = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./system/shell.nix
            ./iso
          ];
        };

        # Referenced where it lives, never copied to
        # hardware-configuration.nix, so it cannot reach a real machine.
        AnNIXion-ci = mkAnnixion ./system/hardware-stub.nix;
      }
      # Absent a real hardware-configuration.nix, "nixos-rebuild
      # --flake .#AnNIXion" fails on the missing attribute rather than
      # silently building someone else's disk layout.
      // nixpkgs.lib.optionalAttrs (builtins.pathExists ./hardware-configuration.nix) {
        AnNIXion = mkAnnixion ./hardware-configuration.nix;
      };

      # Discovered, not listed. ci.yml already asks the flake which checks
      # exist; a VM test that was written and wired in but never added here
      # would evaluate for nobody and run nowhere.
      checks.${system} =
        let
          inherit (nixpkgs) lib;
          # The only one that boots unfree packages — the rest must keep the
          # plain instance or their derivations change for no reason.
          unfree = [ "security-tools" ];
        in
        lib.mapAttrs'
          (
            file: _:
            let
              name = lib.removeSuffix ".nix" file;
              testers = if builtins.elem name unfree then pkgsUnfree.testers else pkgs.testers;
            in
            lib.nameValuePair name (testers.nixosTest (import (./tests/system + "/${file}")))
          )
          (
            lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n) (builtins.readDir ./tests/system)
          );

      devShells.${system}.default = pkgs.mkShell {
        name = "annixion-dev";
        packages = with pkgs; [
          nixfmt
          statix
          deadnix
          shellcheck
          # project-sync.sh and the milestone tests parse JSON with it.
          jq
          # tests/shell/prompt-width.sh renders the real theme to check the ladder.
          oh-my-posh
          # tests/repo/workflow-injection.sh reads the workflows' run: blocks.
          yq-go
          # tests/shell/dns-axfr.sh needs dig; runners do not reliably carry it.
          dnsutils
          # Builds the release SBOM, in CI and by hand: the same pinned version
          # either way, so a locally generated SBOM matches the published one.
          sbomnix
          # render-cve-status.py and the form parsers. Arrives transitively with
          # sbomnix otherwise, which is not something to depend on.
          python3
          nil
          nix-output-monitor
        ];
        shellHook = ''
          # stderr, not stdout: scripts run as 'nix develop --command ... > file'
          # would otherwise find this banner at the top of their output.
          echo "AnNIXion dev shell — .github/scripts/lint.sh runs the linters; docs/dev.md has the rest." >&2
        '';
      };
    };
}
