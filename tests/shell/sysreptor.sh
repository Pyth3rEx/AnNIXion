#!/usr/bin/env bash
# The `sysreptor` wrapper writes the deployment's secrets, and SysReptor
# encrypts the database with them — so a setup that rewrites app.env on a
# second run exits zero and leaves every existing report unreadable. That is
# the failure this test exists for. The rest is the wrapper's contract with
# the upstream compose files: the generated secrets have to land where
# `env_file: ../app.env` resolves, and both external volumes have to be
# created or nothing starts.
#
# Driven against the built script with a stub `docker` on PATH — no daemon, no
# network, no images.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CFG='.#nixosConfigurations.AnNIXion-ci.config'
fails=0

report() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" -eq 0 ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s: %s\n' "$name" "$detail"
    fails=$((fails + 1))
  fi
}

cd "$ROOT" || exit 1

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── The package, as built ──────────────────────────────────────────────────
# Through the flake, not <nixpkgs>: a CI runner sets no channel. The name is
# matched by prefix so a version bump does not have to be mirrored here.
err="$TMP/err"
drv=$(nix eval --raw "$CFG.environment.systemPackages" --apply \
  'ps: (builtins.head (builtins.filter (p: builtins.match "sysreptor-.*" (p.name or "") != null) ps)).drvPath' \
  2>"$err")
out=""
[ -n "$drv" ] && out=$(nix build --no-link --print-out-paths "${drv}^*" 2>>"$err")

if [ -z "$out" ]; then
  printf 'sysreptor: the package did not build\n%s\n' "$(tail -n 5 "$err")"
  exit 1
fi

bin="$out/bin/sysreptor"
report "$([ -x "$bin" ] && echo 0 || echo 1)" \
  "the wrapper is on PATH" "no executable at $bin"

# The API client is the half of this you drive from a shell; it rides in the
# same package, and a dropped join leaves the menu entry working and `reptor`
# gone.
report "$([ -x "$out/bin/reptor" ] && echo 0 || echo 1)" \
  "the reptor API client ships beside it" "no executable at $out/bin/reptor"

help=$("$bin" help 2>&1)
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "help exits zero" "exit $rc"
missing=""
for cmd in setup up down open superuser manage backup restore; do
  grep -q -- "$cmd" <<<"$help" || missing="$missing $cmd"
done
report "$([ -z "$missing" ] && echo 0 || echo 1)" \
  "help names every subcommand" "not documented:$missing"

# ── Preconditions fail as sentences, not as docker errors ──────────────────
# PATH holds no docker; the wrapper's own runtimeInputs still resolve.
nodocker=$(PATH=/var/empty "$bin" status 2>&1)
report "$(grep -q "docker CLI not found" <<<"$nodocker" && echo 0 || echo 1)" \
  "a missing docker CLI is named as such" "said: $nodocker"

noargs=$("$bin" manage 2>&1)
report "$(grep -q "manage needs a command" <<<"$noargs" && echo 0 || echo 1)" \
  "manage without a command says so" "said: $noargs"

badopt=$("$bin" setup --wat 2>&1)
report "$(grep -q "unknown option" <<<"$badopt" && echo 0 || echo 1)" \
  "setup rejects an unknown option" "said: $badopt"

# restorebackup drops the database first, so a restore that reaches docker
# with a mistyped path destroys the reports and restores nothing.
norestore=$("$bin" restore 2>&1)
report "$(grep -q "restore needs a backup file" <<<"$norestore" && echo 0 || echo 1)" \
  "restore without a file says so" "said: $norestore"
badfile=$("$bin" restore "$TMP/not-a-backup.zip" 2>&1)
report "$(grep -q "no such backup file" <<<"$badfile" && echo 0 || echo 1)" \
  "restore checks the file exists before touching the database" "said: $badfile"

# ── A stub daemon, so setup can be driven offline ──────────────────────────
stub="$TMP/stub"
mkdir -p "$stub"
cat >"$stub/docker" <<'STUB'
#!/usr/bin/env bash
log="$DOCKER_STUB_LOG"
printf '%s\n' "$*" >>"$log"
case "$1 $2" in
  "info ") exit 0 ;;
  "volume inspect") exit 1 ;;  # nothing exists yet, so setup must create it
  "volume create") exit 0 ;;
  "compose -f")
    # BIND_PORT is how the wrapper publishes the UI; record what compose saw.
    printf 'BIND_PORT=%s\n' "${BIND_PORT:-<unset>}" >>"$log"
    # An import, or a script piped into `manage.py shell`, reads its input on
    # stdin; drain it so the writer on the other end of the pipe never sees a
    # broken one (set -e on the wrapper turns that SIGPIPE into a silent,
    # confusing abort, with nothing of this printed yet).
    if [[ "$*" == *importdemodata* ]] || [[ "$*" == *"manage.py shell"* ]]; then
      cat >/dev/null
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$stub/docker"

# Never the machine's own /etc/annixion/sysreptor.conf: on a box that has
# rebuilt, that file exists and would decide what these assertions see.
drive() {
  local home="$1"
  shift
  HOME="$home" XDG_DATA_HOME="$home/.local/share" \
    DOCKER_STUB_LOG="$home/docker.log" PATH="$stub:$PATH" \
    ANNIXION_SYSREPTOR_CONF="$home/sysreptor.conf" \
    "$bin" "$@" 2>&1
}

run_setup() {
  local home="$1"
  shift
  drive "$home" setup "$@"
}

home="$TMP/h1"
mkdir -p "$home"
first=$(run_setup "$home")
deploy="$home/.local/share/sysreptor/deploy"

report "$([ -f "$deploy/docker-compose.yml" ] && echo 0 || echo 1)" \
  "setup materialises the pinned deployment" "no compose file under $deploy: $first"

report "$([ -f "$deploy/app.env" ] && echo 0 || echo 1)" \
  "setup writes app.env" "no app.env under $deploy: $first"

# Upstream's app compose names `env_file: ../app.env`, relative to its own
# directory — so the generated file has to sit one level up from it. An
# upstream re-layout moves that path and the app starts with no secrets.
envref=$(grep -rho 'env_file:.*app.env' "$deploy" 2>/dev/null | head -1)
report "$([ -f "$deploy/sysreptor/docker-compose.yml" ] &&
  grep -q '\.\./app\.env' <<<"$envref" && echo 0 || echo 1)" \
  "app.env lands where the compose file looks for it" \
  "the app compose asks for '${envref:-<nothing>}'"

mode=$(stat -c %a "$deploy/app.env" 2>/dev/null)
report "$([ "$mode" = "600" ] && echo 0 || echo 1)" \
  "app.env is readable by its owner only" "mode is ${mode:-<unknown>}"

secret=$(grep '^SECRET_KEY=' "$deploy/app.env")
report "$(grep -q 'TODO-change-me' <<<"$secret" && echo 1 || echo 0)" \
  "the Django secret is generated, not the shipped placeholder" "$secret"
report "$([ "${#secret}" -gt 40 ] && echo 0 || echo 1)" \
  "the generated secret is long enough to be one" "$secret"

report "$(grep -q '^ENCRYPTION_KEYS=' "$deploy/app.env" && echo 0 || echo 1)" \
  "encryption at rest is on by default" "no ENCRYPTION_KEYS in app.env"

# The key id is a reference, not decoration: the app selects the key by it.
keyid=$(sed -n 's/^DEFAULT_ENCRYPTION_KEY_ID="\(.*\)"/\1/p' "$deploy/app.env")
report "$([ -n "$keyid" ] && grep -q "\"id\": \"$keyid\"" "$deploy/app.env" && echo 0 || echo 1)" \
  "the default key id names a key that exists" "id is ${keyid:-<unset>}"

# Unset ALLOWED_HOSTS is what upstream warns about; the bind is local, so the
# wrapper names the local hosts rather than leaving it to a default.
report "$(grep -q '^ALLOWED_HOSTS=' "$deploy/app.env" && echo 0 || echo 1)" \
  "ALLOWED_HOSTS is set rather than left open" "no ALLOWED_HOSTS in app.env"

# Both volumes are `external: true` upstream, so compose creates neither.
created=$(grep -c '^volume create' "$home/docker.log" 2>/dev/null)
report "$([ "${created:-0}" -eq 2 ] && echo 0 || echo 1)" \
  "setup creates both external volumes" "volume create ran ${created:-0} time(s)"

# ── The one that matters: secrets survive a second setup ───────────────────
before=$(cat "$deploy/app.env")
second=$(run_setup "$home")
after=$(cat "$deploy/app.env")
report "$([ "$before" = "$after" ] && echo 0 || echo 1)" \
  "a second setup keeps the existing secrets" \
  "app.env was rewritten — every encrypted report would be unreadable. Said: $second"
report "$(grep -q "keeping the secrets" <<<"$second" && echo 0 || echo 1)" \
  "and says it is keeping them" "said: $second"

# A re-setup still refreshes the deployment itself, which is how a version
# bump reaches an existing install.
rm -f "$deploy/docker-compose.yml"
run_setup "$home" >/dev/null
report "$([ -f "$deploy/docker-compose.yml" ] && echo 0 || echo 1)" \
  "a second setup still refreshes the compose files" "compose file not restored"

# ── Opting out of encryption ───────────────────────────────────────────────
plain="$TMP/h2"
mkdir -p "$plain"
run_setup "$plain" --no-encryption >/dev/null
plainenv="$plain/.local/share/sysreptor/deploy/app.env"
report "$(grep -q '^ENCRYPTION_KEYS=' "$plainenv" && echo 1 || echo 0)" \
  "--no-encryption writes no encryption keys" "ENCRYPTION_KEYS is present anyway"
report "$(grep -q '^SECRET_KEY=' "$plainenv" && echo 0 || echo 1)" \
  "--no-encryption still writes a Django secret" "no SECRET_KEY in app.env"


# ── What the NixOS module writes, and what the wrapper does with it ────────
etcpath='.environment.etc."annixion/sysreptor.conf".text'
conf_default=$(nix eval --raw "$CFG$etcpath" 2>/dev/null)

# The wrapper sources this file, so the test reads it the same way. A Django
# hash is full of `$`: written unquoted, bash would expand `$600000` to the
# sixth positional parameter and the account would be bootstrapped with a
# password nobody holds.
printf '%s\n' "$conf_default" >"$TMP/conf.default"
# shellcheck disable=SC1091 # written just above
read_conf() { (set -u; . "$TMP/conf.default"; eval "printf '%s' \"\${$1:-}\""); }

report "$([ "$(read_conf ANNIXION_SYSREPTOR_BIND)" = "127.0.0.1" ] && echo 0 || echo 1)" \
  "the default config binds loopback only" "bind is $(read_conf ANNIXION_SYSREPTOR_BIND)"
# htb/offsec are opt-in through extraDesigns now — only the in-repo,
# no-fetch annixion pack ships by default.
report "$([ "$(read_conf ANNIXION_SYSREPTOR_DESIGNS)" = "annixion" ] && echo 0 || echo 1)" \
  "only the annixion design is configured by default" "designs are $(read_conf ANNIXION_SYSREPTOR_DESIGNS)"
report "$([ "$(read_conf ANNIXION_SYSREPTOR_EXTRA_PACKS_DIR)" = "" ] && echo 0 || echo 1)" \
  "extraDesigns defaults to no extra packs directory" \
  "EXTRA_PACKS_DIR is '$(read_conf ANNIXION_SYSREPTOR_EXTRA_PACKS_DIR)'"
report "$([ "$(read_conf ANNIXION_SYSREPTOR_ENCRYPT)" = "yes" ] && echo 0 || echo 1)" \
  "encryption at rest is the default" "encrypt is $(read_conf ANNIXION_SYSREPTOR_ENCRYPT)"

hash_declared=$(nix eval --raw "$CFG.annixion.sysreptor.hashedPassword" 2>/dev/null)
hash_read=$(read_conf ANNIXION_SYSREPTOR_HASHED_PASSWORD)
report "$([ -n "$hash_declared" ] && [ "$hash_read" = "$hash_declared" ] && echo 0 || echo 1)" \
  "the password hash survives being sourced by a shell" \
  "declared '$hash_declared', read back '$hash_read'"
report "$(grep -q '^pbkdf2_sha256\$[0-9]*\$' <<<"$hash_read" && echo 0 || echo 1)" \
  "and it is a Django hash rather than a plaintext password" "read back: $hash_read"

mode=$(nix eval --raw "$CFG"'.environment.etc."annixion/sysreptor.conf".mode' 2>/dev/null)
report "$([ "$mode" = "0400" ] && echo 0 || echo 1)" \
  "the file holding that hash is not world-readable" "mode is ${mode:-<unset>}"

# Loopback-only must mean a closed port: an open 8000 with nothing behind it
# is the kind of drift nobody notices.
openports=$(nix eval --json "$CFG.networking.firewall.allowedTCPPorts" 2>/dev/null)
report "$(grep -q '8000' <<<"$openports" && echo 1 || echo 0)" \
  "the firewall stays shut while it is loopback-only" "open TCP ports: $openports"

# The same config with networkAccessible on, so the toggle is asserted rather
# than assumed. extendModules evaluates the variant without a second flake.
variant='c: (c.extendModules { modules = [ { annixion.sysreptor.networkAccessible = true; } ]; }).config'
conf_net=$(nix eval --raw ".#nixosConfigurations.AnNIXion-ci" \
  --apply "$variant"'.environment.etc."annixion/sysreptor.conf".text' 2>/dev/null)
printf '%s\n' "$conf_net" >"$TMP/conf.net"
# shellcheck disable=SC1091 # written just above
read_net() { (set -u; . "$TMP/conf.net"; eval "printf '%s' \"\${$1:-}\""); }
report "$([ "$(read_net ANNIXION_SYSREPTOR_BIND)" = "0.0.0.0" ] && echo 0 || echo 1)" \
  "networkAccessible publishes on every interface" "bind is $(read_net ANNIXION_SYSREPTOR_BIND)"
hostname=$(nix eval --raw "$CFG.networking.hostName" 2>/dev/null)
report "$(grep -q "$hostname" <<<"$(read_net ANNIXION_SYSREPTOR_ALLOWED_HOSTS)" && echo 0 || echo 1)" \
  "and adds the hostname to ALLOWED_HOSTS" \
  "Django would 400 every request to $hostname. Allowed: $(read_net ANNIXION_SYSREPTOR_ALLOWED_HOSTS)"
ports_net=$(nix eval --json ".#nixosConfigurations.AnNIXion-ci" \
  --apply "$variant"'.networking.firewall.allowedTCPPorts' 2>/dev/null)
report "$(grep -q '8000' <<<"$ports_net" && echo 0 || echo 1)" \
  "and opens the port in the firewall" "open TCP ports: $ports_net"


# ── The wrapper reads that file ────────────────────────────────────────────
# No design/template packs exist yet at this point in the build-up — the
# fixtures below ask for none, so the wrapper's own config-sync behaviour is
# exercised without needing a pack to resolve.
conf_home="$TMP/h3"
mkdir -p "$conf_home"
cat >"$conf_home/sysreptor.conf" <<'CONF'
ANNIXION_SYSREPTOR_USER="scribe"
ANNIXION_SYSREPTOR_BIND="0.0.0.0"
ANNIXION_SYSREPTOR_PORT="9001"
ANNIXION_SYSREPTOR_ALLOWED_HOSTS="localhost,127.0.0.1,reports.local"
ANNIXION_SYSREPTOR_ENCRYPT="yes"
ANNIXION_SYSREPTOR_DESIGNS=""
ANNIXION_SYSREPTOR_DEMO_PROJECTS="no"
ANNIXION_SYSREPTOR_FINDING_TEMPLATES=""
CONF

shown=$(drive "$conf_home" config)
report "$(grep -q "user *scribe" <<<"$shown" && echo 0 || echo 1)" \
  "the configured login reaches the wrapper" "config said: $shown"
report "$(grep -q "0.0.0.0:9001" <<<"$shown" && echo 0 || echo 1)" \
  "as does the bind address and port" "config said: $shown"
report "$(grep -q "9001" <<<"$(drive "$conf_home" url)" && echo 0 || echo 1)" \
  "and the URL follows the configured port" "url said: $(drive "$conf_home" url)"

run_setup "$conf_home" >/dev/null
confenv="$conf_home/.local/share/sysreptor/deploy/app.env"
report "$(grep -q '^ALLOWED_HOSTS="localhost,127.0.0.1,reports.local"' "$confenv" && echo 0 || echo 1)" \
  "ALLOWED_HOSTS comes from the config" "app.env has: $(grep '^ALLOWED_HOSTS=' "$confenv")"

# A changed setting has to reach an install that already holds its keys —
# app.env is written once, so the config lines are synced rather than rewritten.
secret_before=$(grep '^SECRET_KEY=' "$confenv")
sed -i 's/,reports.local//' "$conf_home/sysreptor.conf"
drive "$conf_home" up >/dev/null
report "$(grep -q '^ALLOWED_HOSTS="localhost,127.0.0.1"$' "$confenv" && echo 0 || echo 1)" \
  "a changed ALLOWED_HOSTS is synced on the next run" \
  "app.env still has: $(grep '^ALLOWED_HOSTS=' "$confenv")"
report "$([ "$secret_before" = "$(grep '^SECRET_KEY=' "$confenv")" ] && echo 0 || echo 1)" \
  "and the secrets are untouched by that sync" "SECRET_KEY changed"

report "$(grep -q 'BIND_PORT=0.0.0.0:9001:8000' "$conf_home/docker.log" && echo 0 || echo 1)" \
  "compose publishes the configured bind and port" \
  "compose saw: $(grep BIND_PORT "$conf_home/docker.log" | tail -1)"

# ── The health check, so a `designs` run can get past wait_healthy ─────────
health="$TMP/web/api/public/utils/healthcheck"
mkdir -p "$health"
echo ok >"$health/index.html"
hport=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
python3 -m http.server "$hport" --bind 127.0.0.1 -d "$TMP/web" >/dev/null 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null; rm -rf "$TMP"' EXIT
if python3 - "$hport" <<'WAIT'
import sys, time, urllib.request
for _ in range(50):
    try:
        urllib.request.urlopen("http://127.0.0.1:%s/api/public/utils/healthcheck/" % sys.argv[1], timeout=0.2)
        sys.exit(0)
    except Exception:
        time.sleep(0.1)
sys.exit(1)
WAIT
then healthy=0; else healthy=1; fi
report "$healthy" \
  "the stand-in health endpoint answers" "nothing on 127.0.0.1:$hport"

# ── A pack that resolves nowhere fails clearly ──────────────────────────────
# No built-in pack and no extraDesigns means pack_path finds nothing — the
# point of Part B/C is that this is a named error, not a silent no-op. The
# instance answers healthy, so the failure really is pack resolution.
nopack="$TMP/h8"
mkdir -p "$nopack"
cat >"$nopack/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS="htb"
ANNIXION_SYSREPTOR_FINDING_TEMPLATES=""
ANNIXION_SYSREPTOR_DEMO_PROJECTS="no"
CONF
run_setup "$nopack" >/dev/null
said=$(drive "$nopack" designs 2>&1)
report "$(grep -q "no bundled or extra pack called 'design-htb'" <<<"$said" && echo 0 || echo 1)" \
  "a design with no built-in and no extraDesigns pack fails by name" "said: $said"
report "$(grep -q "sysreptor.md" <<<"$said" && echo 0 || echo 1)" \
  "and points at the docs for how to supply one" "said: $said"

# ── The declared login is created once ──────────────────────────────────────
# Re-applying it on every start would silently revert a password changed in
# the UI, which is the only place it can be changed.
# shellcheck disable=SC2016 # a hash, not an expansion — the $ must stay literal
login_hash='pbkdf2_sha256$600000$testsalt$dGVzdGhhc2g='
logins=$(grep -c 'BOOTSTRAP_USERNAME' "$conf_home/docker.log")
report "$([ "${logins:-0}" -eq 0 ] && echo 0 || echo 1)" \
  "no login is bootstrapped without a declared hash" "a shell ran anyway"

acct="$TMP/h6"
mkdir -p "$acct"
cat >"$acct/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_USER="scribe"
ANNIXION_SYSREPTOR_HASHED_PASSWORD='$login_hash'
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS=""
ANNIXION_SYSREPTOR_FINDING_TEMPLATES=""
ANNIXION_SYSREPTOR_DEMO_PROJECTS="no"
CONF

run_setup "$acct" >/dev/null
drive "$acct" up >/dev/null
logins=$(grep -c 'BOOTSTRAP_USERNAME' "$acct/docker.log")
report "$([ "${logins:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "the declared login is created on the first start" "the bootstrap ran ${logins:-0} time(s)"
report "$(grep -q 'BOOTSTRAP_USERNAME=scribe' "$acct/docker.log" && echo 0 || echo 1)" \
  "under the configured name" "compose saw: $(grep -o 'BOOTSTRAP_USERNAME=[^ ]*' "$acct/docker.log" | head -1)"
report "$(grep -qF "BOOTSTRAP_PASSWORD_HASH=$login_hash" "$acct/docker.log" && echo 0 || echo 1)" \
  "with the hash intact, not a shell-mangled one" \
  "compose saw: $(grep -o 'BOOTSTRAP_PASSWORD_HASH=[^ ]*' "$acct/docker.log" | head -1)"

drive "$acct" up >/dev/null
logins=$(grep -c 'BOOTSTRAP_USERNAME' "$acct/docker.log")
report "$([ "${logins:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "a later start never re-applies the password" \
  "the bootstrap ran ${logins:-0} time(s) — a UI password change would have been reverted"

echo
if [ "$fails" -gt 0 ]; then
  printf 'sysreptor: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "sysreptor: deploys from the config, and never rewrites the keys it deployed with"
