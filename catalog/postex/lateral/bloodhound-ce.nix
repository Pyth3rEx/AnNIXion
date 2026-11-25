# BloodHound CE — Active Directory attack-path graph over data a collector
# (bloodhound-python, azurehound, or SharpHound run elsewhere) already
# pulled. Reads and visualises; never reaches the target itself.
#
# Upstream ships no standalone package that starts on its own — the server
# needs Postgres and Neo4j reachable and a config telling it where, which is
# exactly the gap that left this failing to launch the moment it was added
# to the menu as a bare binary. The pinned compose file below, materialised
# into a state dir and driven by the `bloodhound` wrapper, closes it the
# same way catalog/tools/productivity/sysreptor.nix does for SysReptor.
#
# Deployment settings — the admin account's name, the port, whether it is
# reachable off this machine — are system/bloodhound.nix, read at runtime
# from /etc/annixion/bloodhound.conf. See docs/bloodhound.md, and
# docs/hardening.md ("Docker") for the rootless daemon this leans on.
_: {
  package =
    p:
    let
      # Pinned at SpecterOps/BloodHound@75c0a0a, examples/docker-compose/ —
      # the one upstream file actually needed: the app container reads
      # every setting from `bhe_*` environment variables the compose file
      # already wires up, so there is no bloodhound.config.json to carry.
      composeFile = p.fetchurl {
        url = "https://raw.githubusercontent.com/SpecterOps/BloodHound/75c0a0a0e952ff2e8531af167da0091fc6f1f378/examples/docker-compose/docker-compose.yml";
        sha256 = "0s66grdh1704fkx1xx3r3xjn257hzhxyhj4d41py9kllbn6qh8k6";
      };

      driver = p.writeShellApplication {
        name = "bloodhound";
        runtimeInputs = [
          p.coreutils
          p.curl
          p.gnugrep
          p.openssl
          p.xdg-utils # xdg-open, for `bloodhound open`
        ];
        # docker is deliberately not pinned here: system/docker.nix supplies
        # the CLI already carrying the compose plugin this drives.
        text = ''
          composeFile=${composeFile}
          state="''${XDG_DATA_HOME:-$HOME/.local/share}/bloodhound"
          deploy="$state/deploy"

          # Deployment policy, from system/bloodhound.nix. Absent, the
          # defaults below are the same ones that module declares. The path
          # moves for a throwaway second instance, and for the tests.
          conf="''${ANNIXION_BLOODHOUND_CONF:-/etc/annixion/bloodhound.conf}"
          if [ -r "$conf" ]; then
            # shellcheck source=/dev/null
            . "$conf"
          fi
          principal="''${ANNIXION_BLOODHOUND_PRINCIPAL_NAME:-operator}"
          email="''${ANNIXION_BLOODHOUND_EMAIL:-operator@localhost}"
          first_name="''${ANNIXION_BLOODHOUND_FIRST_NAME:-AnNIXion}"
          last_name="''${ANNIXION_BLOODHOUND_LAST_NAME:-Operator}"
          bind="''${ANNIXION_BLOODHOUND_BIND:-127.0.0.1}"
          port="''${ANNIXION_BLOODHOUND_PORT:-8080}"
          expire_now="''${ANNIXION_BLOODHOUND_EXPIRE_NOW:-true}"
          recreate_admin="''${ANNIXION_BLOODHOUND_RECREATE_ADMIN:-false}"

          url="http://127.0.0.1:$port"

          die() { echo "bloodhound: $*" >&2; exit 1; }

          need_docker() {
            command -v docker >/dev/null 2>&1 \
              || die "docker CLI not found — enable annixion.docker (rootless) in your NixOS config."
            docker info >/dev/null 2>&1 \
              || die "cannot reach the docker daemon (rootless starts on first use; try 'systemctl --user start docker')."
          }

          compose() { docker compose -f "$deploy/docker-compose.yml" "$@"; }

          materialise() {
            install -d -m 700 "$state" "$deploy"
            install -m 644 "$composeFile" "$deploy/docker-compose.yml"
          }

          # Database passwords only — generated once and never regenerated,
          # or every graph already collected becomes unreachable the moment
          # the containers restart with a Postgres/Neo4j that no longer
          # recognises them. The admin password is deliberately absent:
          # left unset, BloodHound mints its own strong one on the very
          # first start and prints it once to the app container's log —
          # 'bloodhound logs' is how it is read, same as upstream intends.
          secrets_env() {
            local pg neo
            pg=$(openssl rand -base64 24 | tr -d '\r\n=/+' | head -c 24)
            neo=$(openssl rand -base64 24 | tr -d '\r\n=/+' | head -c 24)
            {
              echo "POSTGRES_USER=bloodhound"
              echo "POSTGRES_PASSWORD=$pg"
              echo "POSTGRES_DB=bloodhound"
              echo "NEO4J_USER=neo4j"
              echo "NEO4J_SECRET=$neo"
            } >"$deploy/.env"
            chmod 600 "$deploy/.env"
          }

          # Configuration rather than secrets, so the NixOS config owns these
          # lines and a changed setting reaches a deploy that already holds
          # its database passwords. Every other line (the two above) is left
          # exactly as written, which is what keeps Postgres and Neo4j able
          # to log back into the data they already created.
          managed='^(BLOODHOUND_HOST|BLOODHOUND_PORT|bhe_default_admin_principal_name|bhe_default_admin_email_address|bhe_default_admin_first_name|bhe_default_admin_last_name|bhe_default_admin_expire_now|bhe_recreate_default_admin)='

          managed_lines() {
            echo "BLOODHOUND_HOST=$bind"
            echo "BLOODHOUND_PORT=$port"
            echo "bhe_default_admin_principal_name=$principal"
            echo "bhe_default_admin_email_address=$email"
            echo "bhe_default_admin_first_name=$first_name"
            echo "bhe_default_admin_last_name=$last_name"
            echo "bhe_default_admin_expire_now=$expire_now"
            echo "bhe_recreate_default_admin=$recreate_admin"
          }

          sync_env() {
            local current desired tmp
            current=$(grep -E "$managed" "$deploy/.env" 2>/dev/null || true)
            desired=$(managed_lines)
            if [ "$current" != "$desired" ]; then
              tmp=$(mktemp "$deploy/.env.XXXXXX")
              chmod 600 "$tmp"
              { grep -vE "$managed" "$deploy/.env" 2>/dev/null || true; } >"$tmp"
              managed_lines >>"$tmp"
              mv "$tmp" "$deploy/.env"
              [ -z "$current" ] || echo "bloodhound: settings changed — 'bloodhound up' to apply."
            fi
          }

          setup() {
            materialise
            if [ -f "$deploy/.env" ]; then
              echo "bloodhound: keeping the database passwords already in $deploy/.env"
            else
              secrets_env
              echo "bloodhound: database passwords written to $deploy/.env"
            fi
            sync_env
            need_docker
            echo "bloodhound: ready — 'bloodhound up', then 'bloodhound logs' for the first admin password."
          }

          ensure() {
            if [ -f "$deploy/docker-compose.yml" ] && [ -f "$deploy/.env" ]; then
              sync_env
            else
              setup
            fi
          }

          wait_healthy() {
            local waited=0
            while [ "$waited" -lt 180 ]; do
              curl -fsS -o /dev/null "$url/" 2>/dev/null && return 0
              sleep 2
              waited=$((waited + 2))
            done
            return 1
          }

          usage() {
            cat <<EOF
          bloodhound — drive the dockerised BloodHound CE graph (Postgres + Neo4j + UI).

          Lifecycle:
            up | down | restart   the app, its database and its graph store
            open                  bring it up and open the UI in a browser
            logs | status         follow logs / list running bloodhound containers
            setup                 materialise the deployment and write database
                                   passwords without starting anything — up/open/
                                   down/restart/logs all do this on their own the
                                   first time, so nothing else needs it run first

          Other:
            config    print the settings in force
            url       print the UI's URL

          Notes:
            - The first start mints the admin account named above and prints
              its password once to the log — 'bloodhound logs' is how you
              read it. There is no login-less mode: Community Edition's
              config carries no flag for one, on this network or off it.
            - Settings come from annixion.bloodhound in your NixOS config,
              not from flags: the port, the admin identity, and whether this
              is reachable off the machine.
            - First 'up' pulls the bloodhound/postgres/neo4j images — slow,
              online. 'bloodhound-python' and 'azurehound' (their own menu
              entries, same Lateral Movement node) collect the data; upload
              what they produce from the UI. SharpHound stays external — a
              Windows-only binary this box cannot run — and downloads from
              the UI's own "Download Collectors" page instead.
          EOF
          }

          cmd="''${1:-help}"; shift || true
          case "$cmd" in
            setup) setup ;;
            up)
              need_docker; ensure
              compose up -d
              echo "bloodhound: $url"
              ;;
            down | restart)
              need_docker; ensure
              compose "$cmd"
              ;;
            logs)
              need_docker; ensure
              compose logs -f
              ;;
            open)
              need_docker; ensure
              compose up -d
              echo "bloodhound: waiting for $url ..."
              wait_healthy || die "no answer from $url after three minutes — check 'bloodhound logs'."
              echo "bloodhound: up at $url"
              xdg-open "$url" >/dev/null 2>&1 &
              ;;
            status) need_docker; docker ps --filter name=bloodhound ;;
            config)
              echo "admin           $principal <$email> ($first_name $last_name)"
              echo "force reset     $expire_now"
              echo "recreate admin  $recreate_admin"
              echo "bind            $bind:$port"
              echo "settings from   $conf (annixion.bloodhound)"
              ;;
            url) echo "$url" ;;
            help | -h | --help) usage ;;
            *) usage; exit 1 ;;
          esac
        '';
      };
    in
    driver;

  name = "BloodHound CE";
  genericName = "AD Attack Path Mapping";
  comment = "Graphs Active Directory attack paths from collected session, ACL and membership data";
  description = ''
    BloodHound CE graphs Active Directory (and Entra ID, via AzureHound)
    attack paths from data a collector already pulled — BloodHound.py,
    AzureHound or SharpHound. It reads and visualises; it never reaches the
    target itself. See docs/bloodhound.md for the deployment this wrapper
    drives, the admin account, and why there is no login-less mode.
  '';
  docs = "https://github.com/SpecterOps/BloodHound";
  snippets = [
    {
      label = "Bring the stack up and open the UI";
      command = "bloodhound open";
    }
    {
      label = "Follow logs (first-run admin password)";
      command = "bloodhound logs";
    }
    {
      label = "Check running containers";
      command = "bloodhound status";
    }
  ];
  exec = "bloodhound open";
  launch = "hold"; # konsole: the first pull is long and the errors are worth reading
  mark = {
    class = "passive";
    body = ''
      <path d="M6.9 20.3c-.9 1.3-2.7 1.6-4 .6-1.2-1-1.4-2.8-.4-4 1-1.2 2.8-1.3 4-.3"/>
      <path d="M19.9 20.3c-.9 1.3-2.7 1.6-4 .6-1.2-1-1.4-2.8-.4-4 1-1.2 2.8-1.3 4-.3"/>
      <path d="M13.6 13.2c-.8 1.1-2.3 1.3-3.4.4-1-.8-1.2-2.4-.3-3.4.8-1 2.4-1.2 3.4-.3"/>
      <path d="M5.3 17.1 10.8 13.5M18.6 17.1 13.4 13.6M12.4 10.3 12 5.7"/>
      <circle cx="12" cy="4.2" r="1.8" fill="@c@" stroke="none"/>
    '';
  };
}
