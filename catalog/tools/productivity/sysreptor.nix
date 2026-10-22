# SysReptor — self-hosted pentest reporting: findings, templates, PDF designs.
#
# Upstream ships no package, only a docker-compose deployment (Django app,
# Postgres, Redis), so the pinned release bundle is materialised into a state
# dir and driven by the `sysreptor` wrapper. `reptor`, the API client that
# pushes findings and tool output into a report, is a native Nix build and the
# half of this you use from a shell.
#
# Deployment settings — the login, the port, whether it is reachable off this
# machine, which designs to import — are system/sysreptor.nix, read at runtime
# from /etc/annixion/sysreptor.conf. See docs/sysreptor.md, and
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

      # Official designs, as `manage.py importdemodata` takes them. Upstream
      # publishes these at an unversioned URL and refreshes them in place, so
      # the hash is the pin — bump it when a new certification design lands.
      designPack =
        name: hash:
        p.fetchurl {
          url = "https://docs.sysreptor.com/assets/${name}.tar.gz";
          sha256 = hash;
        };

      # The launcher's own mark, flattened to one line with single-quoted
      # attributes so it can be substituted into a JSON string. The drawing is
      # catalog/logo.nix; only the colour is decided here.
      logo = import ../../logo.nix { };
      markSvg =
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='-1.3 -1.3 26.6 26.6'>"
        + "<g fill='none' stroke='#FF0033' stroke-width='2.3275' stroke-linecap='round' stroke-linejoin='round'>"
        + builtins.replaceStrings [ "\"" "\n" ] [ "'" " " ] logo.body
        + "</g></svg>";

      # Named <type>-<pack>: the wrapper reads the type back off the filename
      # and hands it to `importdemodata --type=`, which takes design, project
      # or template.
      designs = p.runCommand "sysreptor-designs" { } ''
        d=$out/share/sysreptor/designs
        install -Dm444 ${designPack "htb-designs" "sha256-MrtwvZ48cgzLeA+xw7opIuT4MQ69+PdrS8/lG0GZh2I="} $d/design-htb.tar.gz
        install -Dm444 ${designPack "offsec-designs" "sha256-IAOsPcZgfOmyH2j93pU93+TidyCsSkMcmUCIQjrieUo="} $d/design-offsec.tar.gz
        install -Dm444 ${designPack "demo-designs" "sha256-t4q27uVTIFc2eV784B5aE9H/nePWlKlFE/9k+JbaoDE="} $d/design-demo.tar.gz
        install -Dm444 ${designPack "htb-demo-projects" "sha256-qQF8YXTku/s8X7l16Rb0oQVu4Jsz+mFo6WUeLif9zO8="} $d/project-htb.tar.gz
        install -Dm444 ${designPack "offsec-demo-projects" "sha256-e+UaBoOoWHF0zqlmKd3XUFQFAWqwHq5sU1DjzSmLlDg="} $d/project-offsec.tar.gz
        install -Dm444 ${designPack "demo-projects" "sha256-FgdHfmgg4h2b0sqUQViDoy701D+notxd2hOdBbt4FDo="} $d/project-demo.tar.gz
        install -Dm444 ${designPack "demo-templates" "sha256-t5stjwZ3XAHae0vaGpihw/wk/jTu1YkuOjVu/sFFuko="} $d/template-demo.tar.gz

        # Ours, from assets/sysreptor/templates — one JSON per finding. Fixed
        # order and timestamp, so the archive is byte-identical per rebuild.
        mkdir -p $d
        tar -czf $d/template-annixion.tar.gz \
          --sort=name --mtime=@1 --owner=0 --group=0 --numeric-owner \
          -C ${../../../assets/sysreptor/templates} .
        chmod 444 $d/template-annixion.tar.gz

        # The designs carry the mark inline rather than as an asset file, so
        # it is substituted from catalog/logo.nix at build time and cannot
        # drift from the drawing the launcher wears. Single-quoted attributes:
        # the SVG goes inside a JSON string and must not carry a double quote.
        mkdir -p designs
        cp ${../../../assets/sysreptor/designs}/*.json designs/
        chmod u+w designs/*.json
        for f in designs/*.json; do
          sed -i "s|@LOGO_SVG@|${markSvg}|g" "$f"
        done
        tar -czf $d/design-annixion.tar.gz \
          --sort=name --mtime=@1 --owner=0 --group=0 --numeric-owner \
          -C designs .
        chmod 444 $d/design-annixion.tar.gz
      '';

      driver = p.writeShellApplication {
        name = "sysreptor";
        runtimeInputs = [
          p.coreutils
          p.curl
          p.gnugrep
          p.gnused
          p.openssl
          p.python3 # `sysreptor hash`; already in the closure via reptor
          p.rsync
          p.util-linux # uuidgen, for the encryption key id
          p.xdg-utils # xdg-open, for `sysreptor open`
        ];
        # docker is deliberately not pinned here: system/docker.nix supplies the
        # CLI already carrying the compose plugin this drives.
        text = ''
          deploySrc=${deploySrc}
          packs=${designs}/share/sysreptor/designs
          state="''${XDG_DATA_HOME:-$HOME/.local/share}/sysreptor"
          deploy="$state/deploy"
          imported="$state/imported"

          # Deployment policy, from system/sysreptor.nix. Absent, the defaults
          # below are the same ones that module declares. The path moves for a
          # throwaway second instance, and for the tests.
          conf="''${ANNIXION_SYSREPTOR_CONF:-/etc/annixion/sysreptor.conf}"
          if [ -r "$conf" ]; then
            # shellcheck source=/dev/null
            . "$conf"
          elif [ -e "$conf" ]; then
            # It is 0400 and the operator's: another account reading it would
            # otherwise silently get the defaults instead.
            echo "sysreptor: $conf is not readable by $(id -un) — using defaults." >&2
          fi
          user="''${ANNIXION_SYSREPTOR_USER:-operator}"
          hashed_password="''${ANNIXION_SYSREPTOR_HASHED_PASSWORD:-}"
          bind="''${ANNIXION_SYSREPTOR_BIND:-127.0.0.1}"
          port="''${ANNIXION_SYSREPTOR_PORT:-8000}"
          allowed_hosts="''${ANNIXION_SYSREPTOR_ALLOWED_HOSTS:-localhost,127.0.0.1}"
          encrypt="''${ANNIXION_SYSREPTOR_ENCRYPT:-yes}"
          want_designs="''${ANNIXION_SYSREPTOR_DESIGNS-htb}"
          want_projects="''${ANNIXION_SYSREPTOR_DEMO_PROJECTS:-no}"
          want_templates="''${ANNIXION_SYSREPTOR_FINDING_TEMPLATES-annixion}"
          plugins="''${ANNIXION_SYSREPTOR_PLUGINS:-}"
          theme_file="''${ANNIXION_SYSREPTOR_THEME_FILE:-}"

          url="http://127.0.0.1:$port"
          # Compose interpolates this; the shell beats the .env file.
          export BIND_PORT="$bind:$port:8000"

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
            local secret id key
            secret=$(openssl rand -base64 64 | tr -d '\r\n=')
            {
              echo "# Written by 'sysreptor setup'. Secret, and worth backing up:"
              echo "# without these keys the database cannot be read."
              echo "# Options: https://docs.sysreptor.com/setup/configuration/"
              echo "SECRET_KEY=\"$secret\""
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

          # These lines are configuration rather than secrets, so the NixOS
          # config owns them and a changed setting reaches an install that
          # already holds its keys. Every other line is left exactly as
          # written — which is what keeps the encryption keys intact.
          managed='^(ALLOWED_HOSTS|ENABLED_PLUGINS|PLUGIN_CUSTOMIZETHEME_CONFIG)='

          managed_lines() {
            echo "ALLOWED_HOSTS=\"$allowed_hosts\""
            [ -z "$plugins" ] || echo "ENABLED_PLUGINS=\"$plugins\""
            # Single quotes: the value is JSON, and it travels through a file
            # docker compose parses, not through a shell.
            [ -z "$theme_file" ] || echo "PLUGIN_CUSTOMIZETHEME_CONFIG='$(cat "$theme_file")'"
          }

          sync_app_env() {
            local current desired tmp
            current=$(grep -E "$managed" "$deploy/app.env" || true)
            desired=$(managed_lines)
            if [ "$current" != "$desired" ]; then
              tmp=$(mktemp "$deploy/.app.env.XXXXXX")
              chmod 600 "$tmp"
              { grep -vE "$managed" "$deploy/app.env" || true; } >"$tmp"
              managed_lines >>"$tmp"
              mv "$tmp" "$deploy/app.env"
              # `up`, not `restart`: restart reuses the container it has, and
              # env_file is read when one is created.
              [ -z "$current" ] || echo "sysreptor: settings changed in app.env — 'sysreptor up' to apply."
            fi
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
            case "''${1:-}" in
              --no-encryption) encrypt=no ;;
              "") ;;
              *) die "unknown option '$1' (--no-encryption)" ;;
            esac

            materialise
            if [ -f "$deploy/app.env" ]; then
              echo "sysreptor: keeping the secrets already in $deploy/app.env"
            else
              app_env
              echo "sysreptor: secrets written to $deploy/app.env"
              if [ "$encrypt" = yes ]; then
                echo "sysreptor: encryption at rest is on — back up app.env, or the reports are unreadable."
              fi
            fi
            sync_app_env

            need_docker
            volumes
            echo "sysreptor: ready — 'sysreptor up', then 'sysreptor superuser' for the first login."
          }

          ensure() {
            if [ -f "$deploy/docker-compose.yml" ] && [ -f "$deploy/app.env" ]; then
              sync_app_env
            else
              setup
            fi
          }

          wait_healthy() {
            local waited=0
            while [ "$waited" -lt 180 ]; do
              if curl -fsS "$url/api/public/utils/healthcheck/" >/dev/null 2>&1; then
                return 0
              fi
              sleep 2
              waited=$((waited + 2))
            done
            return 1
          }

          # Which configured packs this install has not seen yet. Importing one
          # twice creates a second copy of every design in it, so the record is
          # what keeps `up` idempotent.
          unimported() { grep -qxF "$1" "$imported" 2>/dev/null || echo "$1"; }

          pending_packs() {
            local pack
            for pack in $want_designs; do
              unimported "design-$pack"
            done
            if [ "$want_projects" = yes ]; then
              for pack in $want_designs; do
                unimported "project-$pack"
              done
            fi
            for pack in $want_templates; do
              unimported "template-$pack"
            done
          }

          import_pack() {
            local pack="$1" kind
            kind=''${pack%%-*}
            [ -f "$packs/$pack.tar.gz" ] || die "no bundled pack called '$pack'."
            echo "sysreptor: importing $pack ..."
            compose exec --no-TTY app python3 manage.py importdemodata \
              --type="$kind" <"$packs/$pack.tar.gz"
            echo "$pack" >>"$imported"
          }

          # The declared login, created once so a fresh install has something
          # to log in as. Never re-applied: a password changed in the UI has
          # to survive the next start, and the config cannot know about it.
          bootstrap_login() {
            [ -n "$hashed_password" ] || return 0
            if grep -qxF login "$imported" 2>/dev/null; then
              return 0
            fi
            wait_healthy || die "no answer from $url — check 'sysreptor logs'."
            compose exec --no-TTY \
              -e BOOTSTRAP_USERNAME="$user" \
              -e BOOTSTRAP_PASSWORD_HASH="$hashed_password" \
              app python3 manage.py shell <<'PY'
          import os
          from django.contrib.auth import get_user_model

          U = get_user_model()
          name = os.environ["BOOTSTRAP_USERNAME"]
          if U.objects.filter(username=name).exists():
              print("sysreptor: the %s login already exists" % name)
          else:
              u = U.objects.create_superuser(username=name, email=None, password=None)
              u.password = os.environ["BOOTSTRAP_PASSWORD_HASH"]
              u.save(update_fields=["password"])
              print("sysreptor: created the %s login" % name)
          PY
            echo login >>"$imported"
          }

          # Django's own format, so the plaintext never reaches the config.
          mint_hash() {
            local pw1 pw2
            read -r -s -p "sysreptor: new password: " pw1; echo
            read -r -s -p "sysreptor: again:        " pw2; echo
            [ -n "$pw1" ] || die "an empty password is not one."
            [ "$pw1" = "$pw2" ] || die "those did not match."
            SYSREPTOR_NEW_PW="$pw1" python3 -c '
          import base64, hashlib, os, secrets, string

          alphabet = string.ascii_letters + string.digits
          salt = "".join(secrets.choice(alphabet) for _ in range(22))
          iterations = 600000
          dk = hashlib.pbkdf2_hmac("sha256", os.environ["SYSREPTOR_NEW_PW"].encode(), salt.encode(), iterations)
          print("pbkdf2_sha256$%d$%s$%s" % (iterations, salt, base64.b64encode(dk).decode()))
          '
            echo "Put that in annixion.sysreptor.hashedPassword, or change the password in the UI." >&2
          }

          import_pending() {
            local pending pack
            pending=$(pending_packs)
            [ -n "$pending" ] || return 0
            echo "sysreptor: waiting for $url before importing designs ..."
            wait_healthy || die "no answer from $url — check 'sysreptor logs', then 'sysreptor designs'."
            for pack in $pending; do
              import_pack "$pack"
            done
          }

          usage() {
            cat <<EOF
          sysreptor — drive the dockerised SysReptor reporting platform.

          Lifecycle:
            setup [--no-encryption]   materialise the deployment, write secrets, create volumes
            up | down | restart       the app, its database and its cache
            open                      bring it up and open the UI in a browser
            logs | status             follow logs / list running sysreptor containers

          Operating:
            superuser [name]          create another login, interactively
            hash                      mint a password hash for the NixOS config
            designs [--force]         import the configured report designs
            manage <args...>          run manage.py inside the app container
            backup [file.zip]         full backup through manage.py backup
            restore <file.zip>        restore one — replaces everything in the database
            env | url | config        print the secrets path / the URL / the settings in force

          Notes:
            - The first start creates the login named above from the password
              hash in the config. There is no login-less mode: every way to
              skip the login screen is Professional-edition only.
            - \`reptor\` (on PATH) is the API client: it pushes findings and tool
              output into a report from the shell. \`reptor conf\` to point it here.
            - Settings come from annixion.sysreptor in your NixOS config, not
              from flags: the port, the login, whether this is reachable off
              the machine, and which designs get imported.
            - First \`up\` pulls the app, Postgres and Redis images — slow, online.
          EOF
          }

          cmd="''${1:-help}"; shift || true
          case "$cmd" in
            setup) setup "''${1:-}" ;;
            up)
              need_docker; ensure
              compose up -d
              bootstrap_login
              import_pending
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
            open)
              need_docker; ensure
              compose up -d
              bootstrap_login
              import_pending
              echo "sysreptor: waiting for $url ..."
              wait_healthy || die "no answer from $url after three minutes — check 'sysreptor logs'."
              echo "sysreptor: up at $url"
              xdg-open "$url" >/dev/null 2>&1 &
              ;;
            status) need_docker; docker ps --filter name=sysreptor ;;
            superuser)
              need_docker; ensure
              compose exec app python3 manage.py createsuperuser --username "''${1:-$user}"
              ;;
            designs)
              need_docker; ensure
              # Importing runs inside the app container, so it has to be up.
              compose up -d
              if [ "''${1:-}" = "--force" ]; then
                rm -f "$imported"
                echo "sysreptor: re-importing — designs already in the UI will gain a second copy."
              fi
              import_pending
              echo "sysreptor: designs in place ($want_designs)"
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
            hash) mint_hash ;;
            env) echo "$deploy/app.env" ;;
            url) echo "$url" ;;
            config)
              echo "user            $user"
              echo "password        $([ -n "$hashed_password" ] && echo "declared (hashed)" || echo "none — create a login by hand")"
              echo "bind            $bind:$port"
              echo "allowed hosts   $allowed_hosts"
              echo "encrypt at rest $encrypt"
              echo "designs         $want_designs"
              echo "example reports $want_projects"
              echo "find. templates $want_templates"
              echo "plugins         ''${plugins:-<the UI decides>}"
              echo "theme           $([ -n "$theme_file" ] && echo "annixion" || echo "upstream")"
              echo "settings from   $conf (annixion.sysreptor)"
              ;;
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
        designs
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
