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
  *) exit 0 ;;
esac
STUB
chmod +x "$stub/docker"

run_setup() {
  local home="$1"
  shift
  HOME="$home" XDG_DATA_HOME="$home/.local/share" \
    DOCKER_STUB_LOG="$home/docker.log" PATH="$stub:$PATH" \
    "$bin" setup "$@" 2>&1
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

echo
if [ "$fails" -gt 0 ]; then
  printf 'sysreptor: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "sysreptor: the wrapper deploys, and never rewrites the keys it deployed with"
