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

  # ── The AnNIXion theme ──────────────────────────────────────────────────
  # Chrome and semantic classes from docs/visual-identity.md. The risk scale
  # keeps the conventional CVSS ramp — red, orange, amber, blue, green — and
  # only borrows AnNIXion's values where they land on it. A report is read by
  # people who know what an orange "High" means; the house style does not get
  # to repaint that, so the orange is a severity colour and nothing else.
  ground = "#0E0F13"; # deepest ground
  surface = "#14171D"; # the menu ground marks are measured against
  raised = "#1A1D24"; # raised surface
  divider = "#2E323D"; # segment, divider
  text = "#DFE4EA"; # primary text
  red = "#FF0033"; # the signature accent
  orange = "#FF9300"; # severity ramp only — not a mark class
  amber = "#FFD000";
  blue = "#4A90FF";
  green = "#33E62B";
  grey = "#7A8494";

  riskColours = {
    "risk-critical" = red;
    "risk-high" = orange;
    "risk-medium" = amber;
    "risk-low" = blue;
    "risk-info" = green;
  };

  statusColours = {
    "retest-open" = red;
    "retest-new" = red;
    "retest-changed" = red;
    "retest-partial" = amber;
    "retest-resolved" = green;
    "retest-accepted" = green;
  };

  theme = {
    all = {
      colors = {
        primary = red;
        "on-primary" = ground;
        "primary-bg" = red;
        "on-primary-bg" = ground;
        secondary = grey;
        "on-secondary" = ground;
        logo = red;
        error = red;
        warning = amber;
        "on-warning" = ground;
        info = blue;
        success = green;
        "search-match" = amber;
        "on-search-match" = ground;
      }
      // riskColours
      // statusColours;
      variables = {
        "header-logo-url" = "data:image/svg+xml;base64,@LOGO@";
        "header-logo-height" = "26px";
      };
    };
    dark = {
      colors = {
        background = ground;
        "on-background" = text;
        inherit surface;
        "on-surface" = text;
        "surface-container" = raised;
        header = surface;
        "on-header" = text;
        drawer = surface;
        "on-drawer" = text;
        "codemirror-selection" = divider;
      };
      variables = {
        "border-color" = text;
        "theme-on-code" = text;
      };
    };
    # The dark theme is the one AnNIXion means; light keeps the accent so a
    # user who switches still lands somewhere recognisable.
    light = {
      colors = {
        primary = red;
        logo = red;
        "on-primary" = "#FFFFFF";
      };
    };
  };

  # The mark as the launcher draws it, so the header logo and the menu icon
  # are one drawing. 1.3 of padding holds the round caps; see
  # home/desktop/icons/default.nix, which renders the same way.
  logo = import ../catalog/logo.nix { };
  logoSvg = pkgs.writeText "annixion-logo.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="-1.3 -1.3 26.6 26.6" width="24" height="24">
    <g fill="none" stroke="${red}" stroke-width="2.3275" stroke-linecap="round" stroke-linejoin="round">
    ${logo.body}  </g>
    </svg>
  '';

  themeJson = pkgs.runCommand "annixion-sysreptor-theme.json" { } ''
    logo=$(base64 -w0 ${logoSvg})
    sed "s|@LOGO@|$logo|" ${pkgs.writeText "theme.json" (builtins.toJSON theme)} > $out
  '';
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
          "demo"
        ]
      );
      default = [
        "annixion"
        "htb"
        "offsec"
        "demo"
      ];
      example = [ "htb" ];
      description = ''
        Official report designs imported the first time the platform starts.
        They are pinned in the catalog entry and imported from the store, so
        a first run needs no network beyond the images themselves.

        All three ship by default: they are a few megabytes between them,
        they are the layouts the reports are actually rendered through, and
        a design you have is one you can copy rather than write. Narrow the
        list if an empty Designs page is worth more than the choice.

        - `annixion` — this distribution's own two. **Engagement Report**
          carries a full-spectrum engagement: reconnaissance and OSINT, social
          engineering with campaign metrics, the physical assessment, the
          attack narrative, and what the defenders saw. **OSINT Report** is an
          intelligence product rather than a pentest one — it leads with
          judgements and confidence, grades its sources on the Admiralty
          scale, and records the legal basis for the collection.
        - `htb` — the Hack The Box set: CPTS, CWES, CDSA, CDEP, CWEE, CAPE,
          CJCA, CWPE and COAE.
        - `offsec` — the OffSec set, OSCP included.
        - `demo` — the three designs behind upstream's online demo
          (Margherita, Matrix, Calzone). Client-report layouts rather than
          certification ones, and the usual starting point for your own.

        Each pack is imported once and then left alone, so a design edited in
        the UI stays edited.
      '';
    };

    findingTemplates = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "annixion"
          "demo"
        ]
      );
      default = [ "annixion" ];
      example = [
        "annixion"
        "demo"
      ];
      description = ''
        Finding-template libraries imported on first start. A template is the
        difference between writing a finding and picking one, and they land in
        their own library rather than in any project.

        - `annixion` — this distribution's own library, in
          `assets/sysreptor/templates`. Application, infrastructure, Active
          Directory, cloud, wireless and endpoint findings, plus the physical
          and social-engineering ones a red team actually reports: tailgating,
          badge cloning, door bypass, pretext calls, MFA fatigue, payment
          fraud. Tagged `red`, `puppet` or `osint` after the three disciplines
          the browser profiles already divide along.
        - `demo` — upstream's ten web findings. Overlaps the above; useful
          mainly to compare wording.

        Both are starting points to edit into your own voice before a client
        reads them.
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

        The header logo goes with it: the mark is rendered from
        `catalog/logo.nix` — the same drawing the launcher wears — and passed
        to the theme as a data URI, so the two cannot drift apart.

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
          ${set "THEME_FILE" (if cfg.theme == "annixion" then "${themeJson}" else "")}
        '';
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.networkAccessible [ cfg.port ];
  };
}
