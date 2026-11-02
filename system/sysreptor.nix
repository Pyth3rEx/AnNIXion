# ── SysReptor — deployment settings for the local reporting platform ─────
# The tool itself is catalog/tools/productivity/sysreptor.nix; this is the
# policy it reads at runtime, written to /etc/annixion/sysreptor.conf. It is
# settings only — nothing here starts a container, and `sysreptor` works
# without the file by falling back to the same defaults.
#
# These are the answers the installer collects on a first install and writes
# into user/configuration.nix. See docs/sysreptor.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.annixion.sysreptor;

  # Packs fetched and pinned outside this repo — see extraDesigns below and
  # docs/sysreptor.md. An empty list joins into an empty directory, which is
  # fine: the conf value below is the empty string in that case anyway, so
  # the wrapper never looks inside it.
  extraPacksDir = pkgs.symlinkJoin {
    name = "sysreptor-extra-packs";
    paths = cfg.extraDesigns;
  };
in
{
  options.annixion.sysreptor = {
    user = lib.mkOption {
      type = lib.types.str;
      default = config.users.users.operator.name;
      example = "operator";
      description = ''
        Login `sysreptor superuser` creates and offers by default. It is the
        platform's own account, unrelated to any Unix user — the password is
        asked for at the prompt rather than declared here, so this file never
        holds one.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = ''
        Host port the UI answers on. Above 1024 so the rootless daemon can
        bind it; below that needs `annixion.docker.rootless = false`.
      '';
    };

    networkAccessible = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Publish the UI on every interface instead of loopback, and open the
        port in the firewall.

        Off, the reports are reachable only from this machine, which is what
        a single operator needs. On, anything that can route here can reach
        the login page over plain HTTP — the deliverables of every engagement
        on the box, behind one password, with the session cookie in clear on
        the wire. Turn it on for a team that needs the same instance, put a
        TLS-terminating proxy in front of it, and add the name that proxy
        answers to to `allowedHosts`.
      '';
    };

    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "localhost"
        "127.0.0.1"
      ]
      ++ lib.optional cfg.networkAccessible config.networking.hostName;
      example = [ "reports.engagement.local" ];
      description = ''
        Host names Django answers to. A request arriving under any other name
        is refused with a 400, which is the defence against a cached link or
        a password reset built from an attacker-supplied Host header.

        The local names are always included; making the instance
        network-accessible adds the machine's hostname. Name the proxy's
        hostname here too when there is one.
      '';
    };

    hashedPassword = lib.mkOption {
      type = lib.types.str;
      # The same password the operator account ships with, hashed the way
      # Django stores one. Shared defaults are a known weakness and the
      # roadmap retires both together, at the point the installer can ask.
      default = "pbkdf2_sha256$600000$1Zx7Fw2rgHIcWI5lftgEYR$9w5SB3pd+ObVoR5XrXwmvIyIwoVRFqPe1S8qLdW6CLM=";
      example = "pbkdf2_sha256$600000$<salt>$<hash>";
      description = ''
        Password for the declared login, as a Django PBKDF2 hash — mint one
        with `sysreptor hash`. The plaintext never enters the config or the
        Nix store, and the hash is encrypted again at rest by the database.

        It bootstraps the account the first time the platform starts, and is
        never applied again: a password changed in the UI stays changed. Set
        this to `""` to create no account at all and use
        `sysreptor superuser` by hand.

        The default is the same one the operator account ships with, which
        means it is public. Change it, or at least change it in the UI after
        the first login — the Community Edition cannot force that, as
        `must_change_password` is a Professional-edition feature.
      '';
    };

    encryptAtRest = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Generate an AES-GCM key at setup and encrypt the database with it.

        On is right for a machine holding client findings, and it has one
        consequence: the key lives in `deploy/app.env` and nowhere else, so
        losing that file loses every report in the database. Back it up off
        the machine. This is read once, when `sysreptor setup` first writes
        the secrets — changing it afterwards does not re-encrypt anything.
      '';
    };

    designs = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "annixion"
          "htb"
          "offsec"
        ]
      );
      default = [ "annixion" ];
      example = [ "htb" ];
      description = ''
        Report designs imported the first time the platform starts.

        - `annixion` — this distribution's own designs, built in-repo from
          `assets/sysreptor/designs` and pinned in the catalog entry with no
          network fetch at all. A first run needs no network beyond the
          container images themselves.
        - `htb` / `offsec` — the Hack The Box and OffSec certification sets.
          Not built by this repo, and not fetched by its CI: naming them
          here does nothing on its own. Populate `extraDesigns` with the
          corresponding packs, fetched and pinned in your own
          `user/configuration.nix` — see docs/sysreptor.md for a worked
          example. Listing one here without a matching `extraDesigns` entry
          makes the import fail with a clear message rather than silently
          doing nothing.

        Each pack is imported once and then left alone, so a design edited in
        the UI stays edited.
      '';
    };

    extraDesigns = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression ''
        let packs = import ../catalog/tools/productivity/sysreptor-packs.nix { inherit pkgs; };
        in [
          (packs.packCmd "design-htb" (packs.designPack "htb-designs" "sha256-..."))
          (packs.packCmd "project-htb" (packs.designPack "htb-demo-projects" "sha256-..."))
        ]
      '';
      description = ''
        Design/project/template packs fetched and pinned outside this
        distribution — HTB, OffSec, or anything else `sysreptor-packs.nix`
        can build. Not built by default and never touched by this repo's CI;
        see docs/sysreptor.md for a worked HTB example. Each package's
        `name` must be `<kind>-<pack>` (e.g. `design-htb`) — the wrapper
        resolves packs by that name.
      '';
    };

    findingTemplates = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "annixion" ]);
      default = [ "annixion" ];
      example = [ ];
      description = ''
        Finding-template libraries imported on first start. A template is the
        difference between writing a finding and picking one, and they land in
        their own library rather than in any project.

        - `annixion` — this distribution's own library, built in-repo from
          `assets/sysreptor/templates`.

        A starting point to edit into your own voice before a client reads
        it.
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "cyberchef"
        "checkthehash"
        "graphqlvoyager"
        "customizetheme"
        "markdownexport"
        "projectnumber"
        "renderfindings"
        "scanimport"
      ];
      example = [ "cyberchef" ];
      description = ''
        Plugins enabled in the application. The default is every official
        plugin that does something in the Community Edition.

        Left out deliberately: `demoplugin`, which exists to demonstrate the
        plugin system, and `webhooks`, `rendersections` and `jira`, which are
        Professional-edition features. `renderfindings` and `scanimport` are
        upstream's own defaults and stay in the list.

        Setting this writes `ENABLED_PLUGINS`, which takes precedence over the
        application's settings page — the plugin checkboxes there become
        read-only. Set this to `[ ]` to hand that control back to the UI.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.enum [
        "annixion"
        "upstream"
      ];
      default = "annixion";
      description = ''
        Which colour scheme the web interface wears. `annixion` applies this
        distribution's palette through the `customizetheme` plugin — the same
        signature red on the same near-black ground the desktop uses, with the
        risk scale drawn from the mark system's semantic classes.

        `upstream` leaves SysReptor's own theme alone.
      '';
    };

    demoProjects = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Also import the filled-in example reports that go with each enabled
        design pack, which show what a finished deliverable looks like. Off
        by default: they appear as projects beside real engagements.
      '';
    };
  };

  config = {
    # Sourced by the `sysreptor` wrapper. Shell syntax rather than JSON so a
    # tool that has to run before any interpreter is available can read it.
    # Every value is shell-quoted: a Django hash is full of `$`, which a
    # double-quoted line would hand to the shell as variables to expand.
    environment.etc."annixion/sysreptor.conf" = {
      # It carries a password hash, so it is the operator's to read.
      user = config.users.users.operator.name;
      mode = "0400";
      text =
        let
          set = k: v: "ANNIXION_SYSREPTOR_${k}=${lib.escapeShellArg v}";
        in
        ''
          # Generated from annixion.sysreptor — edit user/configuration.nix,
          # rebuild, then `sysreptor up` to pick the change up.
          ${set "USER" cfg.user}
          ${set "HASHED_PASSWORD" cfg.hashedPassword}
          ${set "BIND" (if cfg.networkAccessible then "0.0.0.0" else "127.0.0.1")}
          ${set "PORT" (toString cfg.port)}
          ${set "ALLOWED_HOSTS" (lib.concatStringsSep "," cfg.allowedHosts)}
          ${set "ENCRYPT" (if cfg.encryptAtRest then "yes" else "no")}
          ${set "DESIGNS" (lib.concatStringsSep " " cfg.designs)}
          ${set "DEMO_PROJECTS" (if cfg.demoProjects then "yes" else "no")}
          ${set "FINDING_TEMPLATES" (lib.concatStringsSep " " cfg.findingTemplates)}
          ${set "PLUGINS" (lib.concatStringsSep "," cfg.plugins)}
          ${set "EXTRA_PACKS_DIR" (if cfg.extraDesigns == [ ] then "" else "${extraPacksDir}")}
        '';
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.networkAccessible [ cfg.port ];
  };
}
