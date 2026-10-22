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
  ...
}:

let
  cfg = config.annixion.sysreptor;
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
          "htb"
          "offsec"
        ]
      );
      default = [ "htb" ];
      example = [
        "htb"
        "offsec"
      ];
      description = ''
        Official report designs imported the first time the platform starts.
        They are pinned in the catalog entry and imported from the store, so
        a first run needs no network beyond the images themselves.

        `htb` is the Hack The Box set — CPTS, CWES, CDSA, CDEP, CWEE, CAPE,
        CJCA, CWPE and COAE. `offsec` is the OffSec set, OSCP included. Each
        pack is imported once and then left alone, so a design edited in the
        UI stays edited.
      '';
    };

    demoProjects = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Also import Hack The Box's filled-in example reports, which show what
        a finished deliverable looks like in each design. Off by default:
        they appear as projects beside real engagements.
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
        '';
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.networkAccessible [ cfg.port ];
  };
}
