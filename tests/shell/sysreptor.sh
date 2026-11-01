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
    # An import reads the pack on stdin; drain it so the wrapper sees no pipe
    # error and the log line means "a pack really was handed over".
    [[ "$*" == *importdemodata* ]] && cat >/dev/null
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

# ── The report designs ship in the package ─────────────────────────────────
# The HTB set is what the install promises; it is imported from the store, so
# a first run needs no network beyond the images.
packs="$out/share/sysreptor/designs"
for pack in design-htb design-offsec design-demo project-htb project-offsec project-demo template-demo; do
  report "$([ -f "$packs/$pack.tar.gz" ] && echo 0 || echo 1)" \
    "the $pack pack is bundled" "no $packs/$pack.tar.gz"
done

mkdir -p "$TMP/htb"
tar xzf "$packs/design-htb.tar.gz" -C "$TMP/htb" 2>/dev/null
names=$(cat "$TMP"/htb/*.json 2>/dev/null | grep -o '"name": "HTB [A-Z]*' | sort -u)
report "$(grep -q 'HTB CPTS' <<<"$names" && echo 0 || echo 1)" \
  "the HTB pack carries the CPTS design" "found: $(tr '\n' ' ' <<<"$names")"
report "$([ "$(wc -l <<<"$names")" -ge 5 ] && echo 0 || echo 1)" \
  "and the rest of the certification set" "found: $(tr '\n' ' ' <<<"$names")"

# The finding templates are the pack that saves the most typing, so it is
# worth knowing it is really a template library and not an empty archive.
mkdir -p "$TMP/tpl"
tar xzf "$packs/template-demo.tar.gz" -C "$TMP/tpl" 2>/dev/null
titles=$(grep -ho '"title": "[^"]*"' "$TMP"/tpl/*.json 2>/dev/null | sort -u)
report "$(grep -q 'SQL Injection' <<<"$titles" && echo 0 || echo 1)" \
  "the template pack carries written-up findings" \
  "found: $(tr '\n' ' ' <<<"$titles" | head -c 200)"
ntpl=$(find "$TMP/tpl" -maxdepth 1 -name '*.json' | wc -l)
report "$([ "$ntpl" -ge 10 ] && echo 0 || echo 1)" "ten of them" "found $ntpl templates"

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
# Every published design pack ships: they are the layouts a report renders
# through, and an install that has to go and fetch one is an install that
# writes its first report in the wrong design.
default_designs=$(read_conf ANNIXION_SYSREPTOR_DESIGNS)
missing_packs=""
for pack in htb offsec demo; do
  grep -qw "$pack" <<<"$default_designs" || missing_packs="$missing_packs $pack"
done
report "$([ -z "$missing_packs" ] && echo 0 || echo 1)" \
  "every design pack is configured by default" \
  "not imported on a fresh install:$missing_packs (designs are '$default_designs')"
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
conf_home="$TMP/h3"
mkdir -p "$conf_home"
cat >"$conf_home/sysreptor.conf" <<'CONF'
ANNIXION_SYSREPTOR_USER="scribe"
ANNIXION_SYSREPTOR_BIND="0.0.0.0"
ANNIXION_SYSREPTOR_PORT="9001"
ANNIXION_SYSREPTOR_ALLOWED_HOSTS="localhost,127.0.0.1,reports.local"
ANNIXION_SYSREPTOR_ENCRYPT="yes"
ANNIXION_SYSREPTOR_DESIGNS="htb"
ANNIXION_SYSREPTOR_DEMO_PROJECTS="no"
ANNIXION_SYSREPTOR_FINDING_TEMPLATES="no"
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
printf 'design-htb\n' >"$conf_home/.local/share/sysreptor/imported" # nothing to import
drive "$conf_home" up >/dev/null
report "$(grep -q '^ALLOWED_HOSTS="localhost,127.0.0.1"$' "$confenv" && echo 0 || echo 1)" \
  "a changed ALLOWED_HOSTS is synced on the next run" \
  "app.env still has: $(grep '^ALLOWED_HOSTS=' "$confenv")"
report "$([ "$secret_before" = "$(grep '^SECRET_KEY=' "$confenv")" ] && echo 0 || echo 1)" \
  "and the secrets are untouched by that sync" "SECRET_KEY changed"

report "$(grep -q 'BIND_PORT=0.0.0.0:9001:8000' "$conf_home/docker.log" && echo 0 || echo 1)" \
  "compose publishes the configured bind and port" \
  "compose saw: $(grep BIND_PORT "$conf_home/docker.log" | tail -1)"

# ── Designs import once, and only once ─────────────────────────────────────
# importdemodata adds a fresh copy of every design in the pack each time it
# runs, so an `up` that re-imports leaves nine HTB designs after nine starts.
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

imp="$TMP/h4"
mkdir -p "$imp"
cat >"$imp/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS="htb"
ANNIXION_SYSREPTOR_DEMO_PROJECTS="no"
CONF

run_setup "$imp" >/dev/null
first_import=$(drive "$imp" designs)
imports=$(grep -c 'importdemodata --type=design' "$imp/docker.log")
report "$([ "${imports:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "the HTB designs are imported on the first run" \
  "importdemodata ran ${imports:-0} time(s): $first_import"
report "$(grep -qxF 'design-htb' "$imp/.local/share/sysreptor/imported" && echo 0 || echo 1)" \
  "and the import is recorded" "no record under the state dir"
report "$(grep -q 'type=project' "$imp/docker.log" && echo 1 || echo 0)" \
  "the demo projects stay out unless asked for" "a project pack was imported anyway"

drive "$imp" designs >/dev/null
imports=$(grep -c 'importdemodata --type=design' "$imp/docker.log")
report "$([ "${imports:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "a second run imports nothing" "importdemodata ran ${imports:-0} time(s) in total"

drive "$imp" up >/dev/null
imports=$(grep -c 'importdemodata --type=design' "$imp/docker.log")
report "$([ "${imports:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "nor does a later start" "importdemodata ran ${imports:-0} time(s) in total"

drive "$imp" designs --force >/dev/null
imports=$(grep -c 'importdemodata --type=design' "$imp/docker.log")
report "$([ "${imports:-0}" -eq 2 ] && echo 0 || echo 1)" \
  "--force imports again when you ask it to" "importdemodata ran ${imports:-0} time(s) in total"

# ── The declared login is created once ─────────────────────────────────────
# Re-applying it on every start would silently revert a password changed in
# the UI, which is the only place it can be changed.
# shellcheck disable=SC2016 # a hash, not an expansion — the $ must stay literal
login_hash='pbkdf2_sha256$600000$testsalt$dGVzdGhhc2g='
logins=$(grep -c 'manage.py shell' "$imp/docker.log")
report "$([ "${logins:-0}" -eq 0 ] && echo 0 || echo 1)" \
  "no login is bootstrapped without a declared hash" "a shell ran anyway"

acct="$TMP/h6"
mkdir -p "$acct"
cat >"$acct/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_USER="scribe"
ANNIXION_SYSREPTOR_HASHED_PASSWORD='$login_hash'
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS=""
ANNIXION_SYSREPTOR_DEMO_PROJECTS="no"
CONF

run_setup "$acct" >/dev/null
drive "$acct" up >/dev/null
logins=$(grep -c 'manage.py shell' "$acct/docker.log")
report "$([ "${logins:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "the declared login is created on the first start" "manage.py shell ran ${logins:-0} time(s)"
report "$(grep -q 'BOOTSTRAP_USERNAME=scribe' "$acct/docker.log" && echo 0 || echo 1)" \
  "under the configured name" "compose saw: $(grep -o 'BOOTSTRAP_USERNAME=[^ ]*' "$acct/docker.log" | head -1)"
report "$(grep -qF "BOOTSTRAP_PASSWORD_HASH=$login_hash" "$acct/docker.log" && echo 0 || echo 1)" \
  "with the hash intact, not a shell-mangled one" \
  "compose saw: $(grep -o 'BOOTSTRAP_PASSWORD_HASH=[^ ]*' "$acct/docker.log" | head -1)"

drive "$acct" up >/dev/null
logins=$(grep -c 'manage.py shell' "$acct/docker.log")
report "$([ "${logins:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "a later start never re-applies the password" \
  "manage.py shell ran ${logins:-0} time(s) — a UI password change would have been reverted"

proj="$TMP/h5"
mkdir -p "$proj"
cat >"$proj/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS="htb demo"
ANNIXION_SYSREPTOR_DEMO_PROJECTS="yes"
ANNIXION_SYSREPTOR_FINDING_TEMPLATES="yes"
CONF
run_setup "$proj" >/dev/null
drive "$proj" designs >/dev/null
report "$([ "$(grep -c 'importdemodata --type=design' "$proj/docker.log")" -eq 2 ] && echo 0 || echo 1)" \
  "both configured design packs are imported" \
  "design imports: $(grep -c 'importdemodata --type=design' "$proj/docker.log")"
# One per enabled pack, not just HTB's: the example reports are the ones that
# go with the designs actually installed.
report "$([ "$(grep -c 'importdemodata --type=project' "$proj/docker.log")" -eq 2 ] && echo 0 || echo 1)" \
  "the example reports follow the design packs" \
  "project imports: $(grep -c 'importdemodata --type=project' "$proj/docker.log")"
report "$([ "$(grep -c 'importdemodata --type=template' "$proj/docker.log")" -eq 1 ] && echo 0 || echo 1)" \
  "the finding templates are imported once" \
  "template imports: $(grep -c 'importdemodata --type=template' "$proj/docker.log")"

# Default-on, so the install that asks for nothing still gets the library.
report "$([ "$(read_conf ANNIXION_SYSREPTOR_FINDING_TEMPLATES)" = "yes" ] && echo 0 || echo 1)" \
  "finding templates are on by default" \
  "config says $(read_conf ANNIXION_SYSREPTOR_FINDING_TEMPLATES)"

off="$TMP/h7"
mkdir -p "$off"
cat >"$off/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS="htb"
ANNIXION_SYSREPTOR_FINDING_TEMPLATES="no"
CONF
run_setup "$off" >/dev/null
drive "$off" designs >/dev/null
report "$(grep -q 'type=template' "$off/docker.log" && echo 1 || echo 0)" \
  "and stay out when turned off" "a template pack was imported anyway"

echo
if [ "$fails" -gt 0 ]; then
  printf 'sysreptor: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "sysreptor: deploys from the config, ships HTB, and never rewrites its keys"
