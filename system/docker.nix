# ── Docker — container runtime and image tooling ─────────────────────────
# Rootless by default: the docker group is root-equivalent, so a rootful
# daemon hands every desktop process a way around system/hardening.nix.
# Container egress sits outside the VPN killswitch either way.
# Trade-offs and the rootful escape hatch: "Docker" in docs/hardening.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.annixion.docker;
in
{
  options.annixion.docker = {
    enable = lib.mkEnableOption "Docker container runtime and image tooling" // {
      default = true;
    };

    rootless = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run the daemon as the desktop user instead of root. Containers
        then hold no more privilege than the account that started them,
        and no `docker` group exists to join.

        Set false when a container genuinely needs the host network, a
        port below 1024, or raw sockets — none of which rootless grants.
        That also adds the operator to the `docker` group, whose members
        can mount `/` into a container and read or write it as root. It
        is not the fix for a permission error.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.users.users.operator.name;
      description = ''
        Account that owns the rootless daemon, or that joins the `docker`
        group when rootless is off.
      '';
    };

    autoPrune = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Sweep dangling images, stopped containers and unused networks
        weekly. Rootful only — the rootless daemon ships no timer, so
        `docker system prune` stays manual there.
      '';
    };

    tools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        docker-compose # standalone v2, beside the `docker compose` plugin
        lazydocker # TUI over containers, logs and images
        dive # walks an image layer by layer
        ctop # live per-container resource metrics
        skopeo # inspects and copies registry images, no daemon needed
        trivy # scans images for known-vulnerable packages
      ];
      description = ''
        Image and container tooling put on PATH beside the daemon. The
        `docker` CLI is not listed: the runtime module supplies it,
        already carrying the compose and buildx plugins.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { environment.systemPackages = cfg.tools; }

      (lib.mkIf cfg.rootless {
        virtualisation.docker.rootless = {
          enable = true;
          # Without it the CLI looks for the root daemon's socket.
          setSocketVariable = true;
        };
      })

      (lib.mkIf (!cfg.rootless) {
        virtualisation.docker = {
          enable = true;
          # Socket activation still starts it on the first command.
          enableOnBoot = false;
          autoPrune = {
            enable = cfg.autoPrune;
            dates = "weekly";
          };
        };

        users.users.${cfg.user}.extraGroups = [ "docker" ];
      })
    ]
  );
}
