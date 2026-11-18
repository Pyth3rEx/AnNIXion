#!/usr/bin/env bash
# The `bloodhound` wrapper writes the deployment's database passwords, and
# Postgres/Neo4j keep the graph keyed to them — so a setup that rewrites .env
# on a second run exits zero and leaves the database unreachable with its own
# containers. That is the failure this test exists for. The rest is the
# wrapper's contract with annixion.bloodhound: identity and network settings
# reach the deployment, and the database passwords never do.
#
# Driven against the built script with a stub `docker` on PATH — no daemon,
# no network, no images.
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
# Through the flake, not <nixpkgs>: a CI runner sets no channel.
err="$TMP/err"
drv=$(nix eval --raw "$CFG.environment.systemPackages" --apply \
  'ps: (builtins.head (builtins.filter (p: (p.name or "") == "bloodhound") ps)).drvPath' \
  2>"$err")
out=""
[ -n "$drv" ] && out=$(nix build --no-link --print-out-paths "${drv}^*" 2>>"$err")

if [ -z "$out" ]; then
  printf 'bloodhound: the package did not build\n%s\n' "$(tail -n 5 "$err")"
  exit 1
fi

bin="$out/bin/bloodhound"
report "$([ -x "$bin" ] && echo 0 || echo 1)" \
  "the wrapper is on PATH" "no executable at $bin"

help=$("$bin" help 2>&1)
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "help exits zero" "exit $rc"
missing=""
for cmd in setup up down open logs status config url; do
  grep -q -- "$cmd" <<<"$help" || missing="$missing $cmd"
done
report "$([ -z "$missing" ] && echo 0 || echo 1)" \
  "help names every subcommand" "not documented:$missing"

# ── Preconditions fail as sentences, not as docker errors ──────────────────
nodocker=$(PATH=/var/empty "$bin" status 2>&1)
report "$(grep -q "docker CLI not found" <<<"$nodocker" && echo 0 || echo 1)" \
  "a missing docker CLI is named as such" "said: $nodocker"

# ── A stub daemon, so setup can be driven offline ──────────────────────────
stub="$TMP/stub"
mkdir -p "$stub"
cat >"$stub/docker" <<'STUB'
#!/usr/bin/env bash
log="${DOCKER_STUB_LOG:-/dev/null}"
printf '%s\n' "$*" >>"$log"
case "$1 $2" in
  "info ") exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$stub/docker"

# Never the machine's own /etc/annixion/bloodhound.conf: on a box that has
# rebuilt, that file exists and would decide what these assertions see.
drive() {
  local home="$1"
  shift
  HOME="$home" XDG_DATA_HOME="$home/.local/share" \
    DOCKER_STUB_LOG="$home/docker.log" PATH="$stub:$PATH" \
    ANNIXION_BLOODHOUND_CONF="$home/bloodhound.conf" \
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
deploy="$home/.local/share/bloodhound/deploy"

report "$([ -f "$deploy/docker-compose.yml" ] && echo 0 || echo 1)" \
  "setup materialises the pinned compose file" "no compose file under $deploy: $first"

report "$([ -f "$deploy/.env" ] && echo 0 || echo 1)" \
  "setup writes .env" "no .env under $deploy: $first"

mode=$(stat -c %a "$deploy/.env" 2>/dev/null)
report "$([ "$mode" = "600" ] && echo 0 || echo 1)" \
  ".env is readable by its owner only" "mode is ${mode:-<unknown>}"

report "$(grep -q '^POSTGRES_PASSWORD=.\{8,\}' "$deploy/.env" && echo 0 || echo 1)" \
  "a Postgres password is generated" "no POSTGRES_PASSWORD of any length in .env"
report "$(grep -q '^NEO4J_SECRET=.\{8,\}' "$deploy/.env" && echo 0 || echo 1)" \
  "a Neo4j password is generated" "no NEO4J_SECRET of any length in .env"
report "$(grep -q '^bhe_default_admin_password=' "$deploy/.env" && echo 1 || echo 0)" \
  "no admin password is ever written" \
  "bhe_default_admin_password is set — BloodHound should mint and log its own"

# ── The one that matters: database passwords survive a second setup ────────
before=$(cat "$deploy/.env")
second=$(run_setup "$home")
after=$(cat "$deploy/.env")
report "$([ "$before" = "$after" ] && echo 0 || echo 1)" \
  "a second setup keeps the existing database passwords" \
  "env was rewritten — the containers would lose their own database. Said: $second"
report "$(grep -q "keeping the database passwords" <<<"$second" && echo 0 || echo 1)" \
  "and says it is keeping them" "said: $second"

# A re-setup still refreshes the deployment itself, which is how a version
# bump reaches an existing install.
rm -f "$deploy/docker-compose.yml"
run_setup "$home" >/dev/null
report "$([ -f "$deploy/docker-compose.yml" ] && echo 0 || echo 1)" \
  "a second setup still refreshes the compose file" "compose file not restored"

# ── What the NixOS module writes, and what the wrapper does with it ────────
conf_default=$(nix eval --raw "$CFG"'.environment.etc."annixion/bloodhound.conf".text' 2>/dev/null)
printf '%s\n' "$conf_default" >"$TMP/conf.default"
# shellcheck disable=SC1091 # written just above
read_conf() { (set -u; . "$TMP/conf.default"; eval "printf '%s' \"\${$1:-}\""); }

report "$([ "$(read_conf ANNIXION_BLOODHOUND_BIND)" = "127.0.0.1" ] && echo 0 || echo 1)" \
  "the default config binds loopback only" "bind is $(read_conf ANNIXION_BLOODHOUND_BIND)"
report "$([ "$(read_conf ANNIXION_BLOODHOUND_EXPIRE_NOW)" = "true" ] && echo 0 || echo 1)" \
  "forcing a password reset is the default" "expire_now is $(read_conf ANNIXION_BLOODHOUND_EXPIRE_NOW)"

# "symlink" is what an environment.etc entry reports when no mode override
# narrows it from the default — i.e. exactly the "nothing special" case this
# asserts, since the file carries no secret worth restricting.
mode=$(nix eval --raw "$CFG"'.environment.etc."annixion/bloodhound.conf".mode' 2>/dev/null)
report "$([ "$mode" = "symlink" ] && echo 0 || echo 1)" \
  "the conf file carries no secret, so it is not access-restricted" "mode is ${mode:-<unset>}"

openports=$(nix eval --json "$CFG.networking.firewall.allowedTCPPorts" 2>/dev/null)
report "$(grep -q '8080' <<<"$openports" && echo 1 || echo 0)" \
  "the firewall stays shut while it is loopback-only" "open TCP ports: $openports"

# The same config with networkAccessible on, so the toggle is asserted rather
# than assumed. extendModules evaluates the variant without a second flake.
variant='c: (c.extendModules { modules = [ { annixion.bloodhound.networkAccessible = true; annixion.bloodhound.port = 9090; } ]; }).config'
conf_net=$(nix eval --raw ".#nixosConfigurations.AnNIXion-ci" \
  --apply "$variant"'.environment.etc."annixion/bloodhound.conf".text' 2>/dev/null)
printf '%s\n' "$conf_net" >"$TMP/conf.net"
# shellcheck disable=SC1091 # written just above
read_net() { (set -u; . "$TMP/conf.net"; eval "printf '%s' \"\${$1:-}\""); }
report "$([ "$(read_net ANNIXION_BLOODHOUND_BIND)" = "0.0.0.0" ] && echo 0 || echo 1)" \
  "networkAccessible publishes on every interface" "bind is $(read_net ANNIXION_BLOODHOUND_BIND)"
report "$([ "$(read_net ANNIXION_BLOODHOUND_PORT)" = "9090" ] && echo 0 || echo 1)" \
  "and the configured port follows" "port is $(read_net ANNIXION_BLOODHOUND_PORT)"
ports_net=$(nix eval --json ".#nixosConfigurations.AnNIXion-ci" \
  --apply "$variant"'.networking.firewall.allowedTCPPorts' 2>/dev/null)
report "$(grep -q '9090' <<<"$ports_net" && echo 0 || echo 1)" \
  "and opens the configured port in the firewall" "open TCP ports: $ports_net"

# ── The wrapper reads that file ──────────────────────────────────────────
conf_home="$TMP/h3"
mkdir -p "$conf_home"
cat >"$conf_home/bloodhound.conf" <<'CONF'
ANNIXION_BLOODHOUND_PRINCIPAL_NAME="scribe"
ANNIXION_BLOODHOUND_EMAIL="scribe@example.org"
ANNIXION_BLOODHOUND_BIND="0.0.0.0"
ANNIXION_BLOODHOUND_PORT="9001"
ANNIXION_BLOODHOUND_EXPIRE_NOW="false"
ANNIXION_BLOODHOUND_RECREATE_ADMIN="false"
CONF

shown=$(drive "$conf_home" config)
report "$(grep -q "scribe <scribe@example.org>" <<<"$shown" && echo 0 || echo 1)" \
  "the configured admin identity reaches the wrapper" "config said: $shown"
report "$(grep -q "0.0.0.0:9001" <<<"$shown" && echo 0 || echo 1)" \
  "as does the bind address and port" "config said: $shown"
report "$(grep -q "9001" <<<"$(drive "$conf_home" url)" && echo 0 || echo 1)" \
  "and the URL follows the configured port" "url said: $(drive "$conf_home" url)"

run_setup "$conf_home" >/dev/null
confenv="$conf_home/.local/share/bloodhound/deploy/.env"
report "$(grep -q '^bhe_default_admin_principal_name=scribe$' "$confenv" && echo 0 || echo 1)" \
  "the admin identity comes from the config" \
  "env has: $(grep '^bhe_default_admin_principal_name=' "$confenv")"
report "$(grep -q '^bhe_default_admin_expire_now=false$' "$confenv" && echo 0 || echo 1)" \
  "as does forcePasswordChange" "env has: $(grep '^bhe_default_admin_expire_now=' "$confenv")"

# A changed setting has to reach a deploy that already holds its database
# passwords — .env is written once for secrets, so the config lines are
# synced rather than the whole file being rewritten.
pg_before=$(grep '^POSTGRES_PASSWORD=' "$confenv")
sed -i 's/scribe/scribe2/' "$conf_home/bloodhound.conf"
drive "$conf_home" up >/dev/null
report "$(grep -q '^bhe_default_admin_principal_name=scribe2$' "$confenv" && echo 0 || echo 1)" \
  "a changed identity is synced on the next run" \
  "env still has: $(grep '^bhe_default_admin_principal_name=' "$confenv")"
report "$([ "$pg_before" = "$(grep '^POSTGRES_PASSWORD=' "$confenv")" ] && echo 0 || echo 1)" \
  "and the database password is untouched by that sync" "POSTGRES_PASSWORD changed"

echo
if [ "$fails" -gt 0 ]; then
  printf 'bloodhound: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "bloodhound: deploys from the config, and never rewrites the passwords it deployed with"
