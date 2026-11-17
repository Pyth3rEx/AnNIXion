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

      packs = import ../../sysreptor-packs.nix { pkgs = p; };

      # The launcher's own mark, flattened to one line with single-quoted
      # attributes so it can be substituted into a JSON string. The drawing is
      # catalog/logo.nix; only the colour is decided here.
      logo = import ../../logo.nix { };
      markSvg =
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='-1.3 -1.3 26.6 26.6'>"
        + "<g fill='none' stroke='#FF0033' stroke-width='2.3275' stroke-linecap='round' stroke-linejoin='round'>"
        + builtins.replaceStrings [ "\"" "\n" ] [ "'" " " ] logo.body
        + "</g></svg>";

      # Ours, from assets/sysreptor — one JSON per finding and per design. The
      # designs carry the mark inline rather than as an asset file, so it is
      # substituted from catalog/logo.nix at build time and cannot drift from
      # the drawing the launcher wears. Single-quoted attributes: the SVG
      # goes inside a JSON string and must not carry a double quote.
      preparedDesigns = p.runCommand "sysreptor-designs-annixion-src" { } ''
        mkdir -p $out
        cp ${../../../assets/sysreptor/designs}/*.json $out/
        chmod u+w $out/*.json
        for f in $out/*.json; do
          sed -i "s|@LOGO_SVG@|${markSvg}|g" "$f"
        done
      '';

      designAnnixion = packs.packCmd "design-annixion" preparedDesigns;
      templateAnnixion = packs.packCmd "template-annixion" ../../../assets/sysreptor/templates;

      # Named <type>-<pack>: the wrapper reads the type back off the filename
      # and hands it to `importdemodata --type=`, which takes design, project
      # or template. Everything else (HTB, OffSec, ...) is opt-in through
      # annixion.sysreptor.extraDesigns — see sysreptor-packs.nix and
      # docs/sysreptor.md — and never built here.
      designs = p.runCommand "sysreptor-designs" { } ''
        d=$out/share/sysreptor/designs
        mkdir -p $d
        ln -s ${designAnnixion}/design-annixion.tar.gz $d/
        ln -s ${templateAnnixion}/template-annixion.tar.gz $d/
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
          syncpy=${../../../scripts/sysreptor-sync.py}
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
          want_designs="''${ANNIXION_SYSREPTOR_DESIGNS-annixion}"
          want_projects="''${ANNIXION_SYSREPTOR_DEMO_PROJECTS:-no}"
          want_templates="''${ANNIXION_SYSREPTOR_FINDING_TEMPLATES-annixion}"
          plugins="''${ANNIXION_SYSREPTOR_PLUGINS:-}"
          theme_file="''${ANNIXION_SYSREPTOR_THEME_FILE:-}"
          # Packs fetched and pinned outside this repo, by the user, through
          # annixion.sysreptor.extraDesigns — see docs/sysreptor.md. Empty
          # until that option is populated.
          extra_packs="''${ANNIXION_SYSREPTOR_EXTRA_PACKS_DIR:-}"

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

          # Resolves a pack by name — the ones this repo bundles first, then
          # whatever annixion.sysreptor.extraDesigns supplied at runtime. A
          # built-in pack always wins a name collision.
          pack_path() {
            local pack="$1"
            if [ -f "$packs/$pack.tar.gz" ]; then
              printf '%s\n' "$packs/$pack.tar.gz"
            elif [ -n "$extra_packs" ] && [ -f "$extra_packs/$pack.tar.gz" ]; then
              printf '%s\n' "$extra_packs/$pack.tar.gz"
            else
              return 1
            fi
          }

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

          # SysReptor mints a fresh id for every document it imports, so
          # importing a pack twice duplicates it rather than updating it. So
          # the question asked here is not "was this pack imported" but
          # "which of its documents is this instance missing", by name.
          instance_names() {
            python3 "$syncpy" names-script |
              compose exec --no-TTY app python3 manage.py shell 2>/dev/null |
              sed -n '/^__ANNIXION_NAMES_BEGIN__$/,/^__ANNIXION_NAMES_END__$/p' |
              sed '1d;$d'
          }

          import_missing() {
            local pack="$1" allnames="$2" kind have filtered listed count path
            kind=''${pack%%-*}
            path=$(pack_path "$pack") || die "no bundled or extra pack called '$pack' — see the HTB example in docs/sysreptor.md if you meant to supply one via annixion.sysreptor.extraDesigns."
            have="$state/have-$kind"
            sed -n "s/^$kind://p" "$allnames" >"$have"
            filtered="$state/missing-$pack.tar.gz"
            listed="$state/missing-$pack.names"
            if python3 "$syncpy" filter \
                 "$path" "$kind" "$have" "$filtered" 2>"$listed"; then
              count=$(wc -l <"$listed")
              echo "sysreptor: importing $count new document(s) from $pack ..."
              compose exec --no-TTY app python3 manage.py importdemodata \
                --type="$kind" <"$filtered"
            fi
            rm -f "$filtered" "$listed"
          }

          # Example reports are the exception: they are meant to be read and
          # deleted, so a name check would import them again the moment someone
          # tidied up. They stay once-only.
          import_projects_once() {
            local pack path
            for pack in $want_designs; do
              grep -qxF "project-$pack" "$imported" 2>/dev/null && continue
              path=$(pack_path "project-$pack") || continue
              echo "sysreptor: importing project-$pack ..."
              compose exec --no-TTY app python3 manage.py importdemodata \
                --type=project <"$path"
              echo "project-$pack" >>"$imported"
            done
          }

          # Rewrite the documents this repo owns, in place and by name, so a
          # design that changed in the flake reaches an instance that already
          # has a design of that name. Ids are kept, so projects using them keep
          # working. This overwrites edits made in the UI to AnNIXion designs
          # and templates, which is why nothing calls it without being asked.
          update_owned() {
            local pack kind path
            for pack in design-annixion template-annixion; do
              path=$(pack_path "$pack") || continue
              kind=''${pack%%-*}
              python3 "$syncpy" update-script "$path" "$kind" |
                compose exec --no-TTY app python3 manage.py shell 2>/dev/null |
                sed -n "s/^__ANNIXION_UPDATED__ \\(.*\\)/sysreptor: rewrote \\1 document(s) in $pack/p"
            done
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
            local names pack
            [ -n "$want_designs$want_templates" ] || return 0
            echo "sysreptor: waiting for $url before checking designs ..."
            wait_healthy || die "no answer from $url — check 'sysreptor logs', then 'sysreptor designs'."
            names="$state/instance-names"
            instance_names >"$names"
            for pack in $want_designs; do
              import_missing "design-$pack" "$names"
            done
            for pack in $want_templates; do
              import_missing "template-$pack" "$names"
            done
            [ "$want_projects" = yes ] && import_projects_once
            rm -f "$names"
            return 0
          }

          # Remove a pack's templates from the instance. The ids come out of
          # the bundled pack, so this deletes exactly what that pack imported
          # and nothing a person wrote.
          prune_pack() {
            local pack="$1" path ids count
            path=$(pack_path "template-$pack") || die "no bundled or extra pack called '$pack' — see the HTB example in docs/sysreptor.md if you meant to supply one via annixion.sysreptor.extraDesigns."
            ids=$(tar -xzOf "$path" --wildcards '*.json' |
              python3 -c '
          import json, re, sys

          # The archive concatenates one JSON document per template.
          raw = sys.stdin.read()
          print(" ".join(re.findall(r"\"id\": \"([0-9a-f-]{36})\"", raw)[::1]))
          ')
            [ -n "$ids" ] || die "found no template ids in the $pack pack."
            count=$(wc -w <<<"$ids")

            if [ -t 0 ]; then
              read -r -p "sysreptor: delete up to $count templates imported from '$pack'? [y/N] " answer
              case "$answer" in
                y | Y | yes) ;;
                *) die "cancelled." ;;
              esac
            fi

            compose exec --no-TTY -e PRUNE_IDS="$ids" app python3 manage.py shell <<'PY'
          import os
          from sysreptor.pentests.models import FindingTemplate

          ids = os.environ["PRUNE_IDS"].split()
          qs = FindingTemplate.objects.filter(id__in=ids)
          print("sysreptor: removing %d templates" % qs.count())
          qs.delete()
          PY
            # Forget the record too, so the pack can be imported again later.
            if [ -f "$imported" ]; then
              grep -vxF "template-$pack" "$imported" >"$imported.tmp" || true
              mv "$imported.tmp" "$imported"
            fi
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
            designs [--update]        import designs the instance is missing;
                                      --update also rewrites the AnNIXion ones
                                      from this build, replacing UI edits to them
            templates prune <pack>    remove the templates a pack imported
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
            templates)
              [ "''${1:-}" = prune ] || die "usage: sysreptor templates prune <pack>"
              [ -n "''${2:-}" ] || die "prune needs a pack name, e.g. 'sysreptor templates prune annixion'"
              need_docker; ensure
              compose up -d
              wait_healthy || die "no answer from $url — check 'sysreptor logs'."
              prune_pack "$2"
              ;;
            designs)
              need_docker; ensure
              # Importing runs inside the app container, so it has to be up.
              compose up -d
              import_pending
              if [ "''${1:-}" = "--update" ]; then
                echo "sysreptor: rewriting the AnNIXion designs and templates in place —"
                echo "           any edit made to them in the UI is replaced."
                update_owned
              fi
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
