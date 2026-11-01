# SysReptor — self-hosted pentest reporting: findings, templates, PDF designs.
#
# Upstream ships no package, only a docker-compose deployment (Django app,
# Postgres, Redis), so the pinned release bundle is materialised into a state
# dir and driven by the `sysreptor` wrapper. `reptor`, the API client that
# pushes findings and tool output into a report, is a native Nix build and the
# half of this you use from a shell. See docs/sysreptor.md, and
# docs/hardening.md ("Docker") for the rootless daemon it leans on.
_: {
  package =
    p:
    let
      version = "2026.95";

      # The release bundle is the compose files and the env template — 9 kB.
      # The images themselves come from the registry on first `up`.
      deploySrc = p.fetchzip {
        url = "https://github.com/Syslifters/sysreptor/releases/download/${version}/setup.tar.gz";
        sha256 = "sha256-GZV0QJc4gvOTnawX/YQHt5ZTjOXQ9d4Rh2v0TmqKN30=";
      };

      driver = p.writeShellApplication {
        name = "sysreptor";
        runtimeInputs = [
          p.coreutils
          p.curl
          p.openssl
          p.rsync
          p.util-linux # uuidgen, for the encryption key id
          p.xdg-utils # xdg-open, for `sysreptor open`
        ];
        # docker is deliberately not pinned here: system/docker.nix supplies the
        # CLI already carrying the compose plugin this drives.
        text = ''
          deploySrc=${deploySrc}
          url="http://127.0.0.1:8000"
          state="''${XDG_DATA_HOME:-$HOME/.local/share}/sysreptor"
          deploy="$state/deploy"

          die() { echo "sysreptor: $*" >&2; exit 1; }

          need_docker() {
            command -v docker >/dev/null 2>&1 \
              || die "docker CLI not found — enable annixion.docker (rootless) in your NixOS config."
            docker info >/dev/null 2>&1 \
              || die "cannot reach the docker daemon (rootless starts on first use; try 'systemctl --user start docker')."
          }

          compose() { docker compose -f "$deploy/docker-compose.yml" "$@"; }

          # Refresh the pinned deployment, never the generated secrets.
          materialise() {
            install -d -m 700 "$state"
            rsync -a --chmod=u+w --delete --exclude app.env "$deploySrc/deploy/" "$deploy/"
          }

          # Written once. Regenerating these orphans everything the old keys
          # encrypted, so setup refuses to overwrite an app.env that exists.
          app_env() {
            local encrypt="$1" secret id key
            secret=$(openssl rand -base64 64 | tr -d '\r\n=')
            {
              echo "# Written by 'sysreptor setup'. Secret, and worth backing up:"
              echo "# without these keys the database cannot be read."
              echo "# Options: https://docs.sysreptor.com/setup/configuration/"
              echo "SECRET_KEY=\"$secret\""
              echo "ALLOWED_HOSTS=\"localhost,127.0.0.1\""
              echo "DEBUG=off"
              if [ "$encrypt" = yes ]; then
                id=$(uuidgen)
                key=$(openssl rand -base64 32 | tr -d '\r\n')
                echo "ENCRYPTION_KEYS=[{\"id\": \"$id\", \"key\": \"$key\", \"cipher\": \"AES-GCM\", \"revoked\": false}]"
                echo "DEFAULT_ENCRYPTION_KEY_ID=\"$id\""
              fi
            } >"$deploy/app.env"
            chmod 600 "$deploy/app.env"
          }

          # The compose file declares both volumes external, so nothing starts
          # until they exist.
          volumes() {
            local v
            for v in sysreptor-db-data sysreptor-app-data; do
              docker volume inspect "$v" >/dev/null 2>&1 || docker volume create "$v" >/dev/null
            done
          }

          setup() {
            local encrypt=yes
            case "''${1:-}" in
              --no-encryption) encrypt=no ;;
              "") ;;
              *) die "unknown option '$1' (--no-encryption)" ;;
            esac

            materialise
            if [ -f "$deploy/app.env" ]; then
              echo "sysreptor: keeping the secrets already in $deploy/app.env"
            else
              app_env "$encrypt"
              echo "sysreptor: secrets written to $deploy/app.env"
              if [ "$encrypt" = yes ]; then
                echo "sysreptor: encryption at rest is on — back up app.env, or the reports are unreadable."
              fi
            fi

            need_docker
            volumes
            echo "sysreptor: ready — 'sysreptor up', then 'sysreptor superuser' for the first login."
          }

          ensure() { [ -f "$deploy/docker-compose.yml" ] || setup; }

          open_ui() {
            compose up -d
            echo "sysreptor: waiting for $url ..."
            local waited=0
            while [ "$waited" -lt 120 ]; do
              if curl -fsS "$url/api/public/utils/healthcheck/" >/dev/null 2>&1; then
                echo "sysreptor: up at $url"
                xdg-open "$url" >/dev/null 2>&1 &
                return 0
              fi
              sleep 2
              waited=$((waited + 2))
            done
            die "no answer from $url after two minutes — check 'sysreptor logs'."
          }

          usage() {
            cat <<'EOF'
          sysreptor — drive the dockerised SysReptor reporting platform.

          Lifecycle:
            setup [--no-encryption]   materialise the deployment, write secrets, create volumes
            up | down | restart       the app, its database and its cache
            open                      bring it up and open the UI in a browser
            logs | status             follow logs / list running sysreptor containers

          Operating:
            superuser [name]          create a login (default: operator)
            manage <args...>          run manage.py inside the app container
            backup [file.zip]         full backup through manage.py backup
            restore <file.zip>        restore one — replaces everything in the database
            env | url                 print the secrets path / the local URL

          Notes:
            - `reptor` (on PATH) is the API client: it pushes findings and tool
              output into a report from the shell. `reptor conf` to point it here.
            - The UI binds 127.0.0.1:8000 only, which rootless docker can serve.
            - First `up` pulls the app, Postgres and Redis images — slow, online.
          EOF
          }

          cmd="''${1:-help}"; shift || true
          case "$cmd" in
            setup) setup "''${1:-}" ;;
            up)
              need_docker; ensure
              compose up -d
              echo "sysreptor: $url"
              ;;
            down | restart)
              need_docker; ensure
              compose "$cmd"
              ;;
            logs)
              need_docker; ensure
              compose logs -f
              ;;
            open) need_docker; ensure; open_ui ;;
            status) need_docker; docker ps --filter name=sysreptor ;;
            superuser)
              need_docker; ensure
              compose exec app python3 manage.py createsuperuser --username "''${1:-operator}"
              ;;
            manage)
              [ "$#" -gt 0 ] || die "manage needs a command, e.g. 'sysreptor manage help'"
              need_docker; ensure
              # A one-shot container, so a piped stdin reaches manage.py.
              if [ -t 0 ]; then
                compose run --rm app python3 manage.py "$@"
              else
                compose run --rm --no-TTY app python3 manage.py "$@"
              fi
              ;;
            backup)
              need_docker; ensure
              out="''${1:-sysreptor-backup-$(date +%Y%m%d-%H%M%S).zip}"
              compose run --rm --no-TTY app python3 manage.py backup >"$out"
              echo "sysreptor: backup written to $out"
              ;;
            restore)
              [ "$#" -gt 0 ] || die "restore needs a backup file, e.g. 'sysreptor restore engagement.zip'"
              [ -f "$1" ] || die "no such backup file: $1"
              need_docker; ensure
              # restorebackup drops everything already in the database.
              if [ -t 0 ]; then
                read -r -p "sysreptor: this deletes the current reports. Restore $1? [y/N] " answer
                case "$answer" in
                  y | Y | yes) ;;
                  *) die "cancelled." ;;
                esac
              fi
              compose run --rm --no-TTY app python3 manage.py restorebackup <"$1"
              echo "sysreptor: restored from $1"
              ;;
            env) echo "$deploy/app.env" ;;
            url) echo "$url" ;;
            help | -h | --help) usage ;;
            *) usage; exit 1 ;;
          esac
        '';
      };
    in
    p.symlinkJoin {
      name = "sysreptor-${version}";
      paths = [
        p.python3Packages.reptor
        driver
      ];
    };

  name = "SysReptor";
  genericName = "Pentest Reporting Platform";
  comment = "Self-hosted pentest reporting — findings, templates, PDF export";
  exec = "sysreptor open";
  launch = "hold"; # konsole: the first pull is long and the errors are worth reading
  mark = {
    class = "utility";
    body = ''
      <path d="M2.4 18.9q9.7.6 19.3-.4"/>
      <path d="M7.1 18.7q-.5-3.1.3-6.2"/>
      <path d="M12.3 18.8q.5-5.3-.3-10.6"/>
      <path d="M17.5 18.6q-.4-7.1.4-13.9"/>
      <path d="M4.7 19.4q.4 2.1.1 3.3"/>
    '';
  };
}
