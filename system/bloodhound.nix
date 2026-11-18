# ── BloodHound CE — deployment settings for the local AD attack-path mapper ─
# The tool itself is catalog/postex/lateral/bloodhound-ce.nix; this is the
# policy it reads at runtime, written to /etc/annixion/bloodhound.conf. It is
# settings only — nothing here starts a container, and `bloodhound` works
# without the file by falling back to the same defaults.
#
# These are the answers the installer collects on a first install and writes
# into user/configuration.nix. See docs/bloodhound.md.
{ config, lib, ... }:

let
  cfg = config.annixion.bloodhound;
in
{
  options.annixion.bloodhound = {
    principalName = lib.mkOption {
      type = lib.types.str;
      default = config.users.users.operator.name;
      example = "operator";
      description = ''
        Login name for the admin account BloodHound creates the first time
        it starts. It is the platform's own account, unrelated to any Unix
        user. The password is never declared here — see below.
      '';
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.principalName}@localhost";
      description = "Email address attached to that admin account.";
    };

    firstName = lib.mkOption {
      type = lib.types.str;
      default = "AnNIXion";
      description = "First name attached to the admin account.";
    };

    lastName = lib.mkOption {
      type = lib.types.str;
      default = "Operator";
      description = "Last name attached to the admin account.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Host port the UI answers on.";
    };

    networkAccessible = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Publish the UI on every interface instead of loopback, and open the
        port in the firewall.

        Off, the graph is reachable only from this machine, which is what a
        single operator needs. On, anything that can route here can reach
        the login page over plain HTTP — every host, user, group and ACL
        edge collected off the target domain, behind one password. Turn it
        on for a team sharing one instance and put a TLS-terminating proxy
        in front of it.

        There is no way to serve the UI with no login at all, on this
        network or off it: Community Edition's config was checked key by
        key for an auth-bypass flag and carries none. The closest it offers
        is `forcePasswordChange` below, which skips only the forced
        *reset* of the first password, never the login screen itself.
      '';
    };

    forcePasswordChange = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Make the admin account change its password the first time it logs
        in. On is the secure default upstream ships — maps to
        `default_admin.expire_now`. Off suits a headless box queried by an
        automated tool that will never open the UI to clear that prompt.
      '';
    };

    recreateDefaultAdmin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Recreate the admin account above on every start if it is missing —
        lockout recovery. Off normally, so deleting the account in the UI
        stays deleted rather than reappearing on the next start.
      '';
    };
  };

  config = {
    # Sourced by the `bloodhound` wrapper. Shell syntax rather than JSON so a
    # tool that has to run before any interpreter is available can read it.
    environment.etc."annixion/bloodhound.conf" = {
      text =
        let
          set = k: v: "ANNIXION_BLOODHOUND_${k}=${lib.escapeShellArg v}";
          bool = b: if b then "true" else "false";
        in
        ''
          # Generated from annixion.bloodhound — edit user/configuration.nix,
          # rebuild, then `bloodhound up` to pick the change up. Carries no
          # secret: the admin password is minted by BloodHound itself on its
          # first start and printed once to `bloodhound logs`.
          ${set "PRINCIPAL_NAME" cfg.principalName}
          ${set "EMAIL" cfg.email}
          ${set "FIRST_NAME" cfg.firstName}
          ${set "LAST_NAME" cfg.lastName}
          ${set "BIND" (if cfg.networkAccessible then "0.0.0.0" else "127.0.0.1")}
          ${set "PORT" (toString cfg.port)}
          ${set "EXPIRE_NOW" (bool cfg.forcePasswordChange)}
          ${set "RECREATE_ADMIN" (bool cfg.recreateDefaultAdmin)}
        '';
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.networkAccessible [ cfg.port ];
  };
}
