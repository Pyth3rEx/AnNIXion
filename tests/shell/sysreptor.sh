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

noprune=$("$bin" templates 2>&1)
report "$(grep -q "templates prune" <<<"$noprune" && echo 0 || echo 1)" \
  "templates without a subcommand says what it takes" "said: $noprune"
badpack=$("$bin" templates prune 2>&1)
report "$(grep -q "prune needs a pack name" <<<"$badpack" && echo 0 || echo 1)" \
  "prune without a pack says so" "said: $badpack"

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
    names="${DOCKER_STUB_NAMES:-/dev/null}"
    if [[ "$*" == *importdemodata* ]]; then
      # Behave like the database the wrapper is reconciling against: remember
      # the names the pack carried, so a later query answers the way an
      # instance that already holds them would. Without this the stub would
      # report an empty instance for ever and every run would re-import.
      kind=$(printf '%s' "$*" | sed -n 's/.*--type=\([a-z]*\).*/\1/p')
      tmp=$(mktemp)
      cat >"$tmp"
      if [ -s "$tmp" ] && [ -n "${DOCKER_STUB_SYNC:-}" ]; then
        python3 "$DOCKER_STUB_SYNC" names "$tmp" "$kind" 2>/dev/null |
          sed "s/^/$kind:/" >>"$names"
      fi
      rm -f "$tmp"
      exit 0
    fi
    if [[ "$*" == *"manage.py shell"* ]]; then
      script=$(cat)
      if [[ "$script" == *__ANNIXION_NAMES__* ]]; then
        printf '__ANNIXION_NAMES_BEGIN__\n'
        [ -f "$names" ] && cat "$names"
        printf '__ANNIXION_NAMES_END__\n'
      fi
      exit 0
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
    DOCKER_STUB_NAMES="$home/instance-names" \
    DOCKER_STUB_SYNC="$ROOT/scripts/sysreptor-sync.py" \
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
for pack in design-annixion design-htb design-offsec design-demo project-htb project-offsec project-demo template-demo template-annixion; do
  report "$([ -f "$packs/$pack.tar.gz" ] && echo 0 || echo 1)" \
    "the $pack pack is bundled" "no $packs/$pack.tar.gz"
done

mkdir -p "$TMP/htb"
tar xzf "$packs/design-htb.tar.gz" -C "$TMP/htb" 2>/dev/null
chmod -R u+w "$TMP/htb"
names=$(cat "$TMP"/htb/*.json 2>/dev/null | grep -o '"name": "HTB [A-Z]*' | sort -u)
report "$(grep -q 'HTB CPTS' <<<"$names" && echo 0 || echo 1)" \
  "the HTB pack carries the CPTS design" "found: $(tr '\n' ' ' <<<"$names")"
report "$([ "$(wc -l <<<"$names")" -ge 5 ] && echo 0 || echo 1)" \
  "and the rest of the certification set" "found: $(tr '\n' ' ' <<<"$names")"

# The finding templates are the pack that saves the most typing, so it is
# worth knowing it is really a template library and not an empty archive.
mkdir -p "$TMP/tpl"
tar xzf "$packs/template-demo.tar.gz" -C "$TMP/tpl" 2>/dev/null
chmod -R u+w "$TMP/tpl"
titles=$(grep -ho '"title": "[^"]*"' "$TMP"/tpl/*.json 2>/dev/null | sort -u)
report "$(grep -q 'SQL Injection' <<<"$titles" && echo 0 || echo 1)" \
  "the template pack carries written-up findings" \
  "found: $(tr '\n' ' ' <<<"$titles" | head -c 200)"
ntpl=$(find "$TMP/tpl" -maxdepth 1 -name '*.json' | wc -l)
report "$([ "$ntpl" -ge 10 ] && echo 0 || echo 1)" "ten of them" "found $ntpl templates"

# ── This distribution's own template library ───────────────────────────────
# Built from assets/sysreptor/templates, so a template added there has to
# reach the pack — and the physical and social-engineering findings are the
# half no upstream library ships.
mkdir -p "$TMP/own"
tar xzf "$packs/template-annixion.tar.gz" -C "$TMP/own" 2>/dev/null
chmod -R u+w "$TMP/own"
nown=$(find "$TMP/own" -maxdepth 1 -name '*.json' | wc -l)
nsrc=$(find "$ROOT/assets/sysreptor/templates" -maxdepth 1 -name '*.json' | wc -l)
report "$([ "$nown" -eq "$nsrc" ] && echo 0 || echo 1)" \
  "every authored template reaches the pack" \
  "$nsrc under assets/, $nown in the archive"
report "$([ "$nown" -ge 100 ] && echo 0 || echo 1)" \
  "the library is an extensive one" "only $nown templates"

# Each discipline has to be covered in depth, not just represented: an area
# with three templates in it is a gap wearing a tag.
for tag in red puppet osint; do
  n=$(grep -l "\"$tag\"" "$TMP"/own/*.json | wc -l)
  report "$([ "$n" -ge 20 ] && echo 0 || echo 1)" \
    "the $tag discipline is covered in depth" "only $n templates tagged $tag"
done
for tag in physical social; do
  n=$(grep -l "\"$tag\"" "$TMP"/own/*.json | wc -l)
  report "$([ "$n" -ge 15 ] && echo 0 || echo 1)" \
    "the $tag area is covered in depth" "only $n templates tagged $tag"
done

# ── The matrices, and what the library reaches of them ─────────────────────
# Both are checked in rather than fetched, so a build stays offline and a
# design does not change shape because an upstream page was regenerated. The
# mapping on a template is only worth having if every id in it resolves, and
# the library is only comprehensive if it reaches every tactic of both.
matrixout=$(python3 - "$ROOT/assets/sysreptor/matrices" "$TMP/own" <<'MATRIX'
import glob, json, os, sys

root, tpl = sys.argv[1], sys.argv[2]
attack = json.load(open(os.path.join(root, "mitre-attack.json")))
disarm = json.load(open(os.path.join(root, "disarm.json")))
AT = {t["id"]: t for t in attack["techniques"]}
DI = {t["id"]: t for t in disarm["techniques"]}

bad, at_tac, di_tac, mapped = [], set(), set(), 0
for path in glob.glob(os.path.join(tpl, "*.json")):
    data = json.load(open(path))["translations"][0]["data"]
    hit = False
    for key, store, tactics in (("attack_techniques", AT, at_tac),
                                ("disarm_techniques", DI, di_tac)):
        for m in data.get(key, []):
            hit = True
            tid = m["technique"].split(" — ")[0]
            if tid not in store:
                bad.append("%s: %s" % (os.path.basename(path), tid))
                continue
            t = store[tid]
            tactics.update(t["tactics"] if key == "attack_techniques" else [t["tactic"]])
    mapped += hit

print("attack_tactics=%d/%d" % (len(at_tac), len(attack["tactics"])))
print("disarm_tactics=%d/%d" % (len(di_tac), len(disarm["tactics"])))
print("mapped=%d" % mapped)
print("bad=%d" % len(bad))
print("attack_missing=%s" % ",".join(
    sorted(t["id"] for t in attack["tactics"] if t["id"] not in at_tac)))
print("disarm_missing=%s" % ",".join(
    sorted(t["id"] for t in disarm["tactics"] if t["id"] not in di_tac)))
MATRIX
)
getv() { sed -n "s/^$1=//p" <<<"$matrixout"; }

report "$([ -f "$ROOT/assets/sysreptor/matrices/mitre-attack.json" ] &&
  [ -f "$ROOT/assets/sysreptor/matrices/disarm.json" ] && echo 0 || echo 1)" \
  "both matrices are checked in" "a matrix file is missing"
report "$([ "$(getv bad)" = "0" ] && echo 0 || echo 1)" \
  "every technique id on a template resolves in its matrix" \
  "$(getv bad) id(s) do not resolve"
report "$([ "$(getv attack_missing)" = "" ] && echo 0 || echo 1)" \
  "the library reaches every ATT&CK tactic" \
  "nothing maps to: $(getv attack_missing)"
report "$([ "$(getv disarm_missing)" = "" ] && echo 0 || echo 1)" \
  "the library reaches every DISARM tactic" \
  "nothing maps to: $(getv disarm_missing)"
nmapped=$(getv mapped)
report "$([ "${nmapped:-0}" -ge 150 ] && echo 0 || echo 1)" \
  "most templates carry a framework mapping" "only ${nmapped:-0} are mapped"

# The influence design is the one that has to carry DISARM, and the engagement
# ATT&CK — that is what makes the mapping appendix in each of them work.
report "$(grep -q 'disarm_techniques' "$ROOT/assets/sysreptor/designs/annixion-influence.json" &&
  grep -q 'DISARM Mapping' "$ROOT/assets/sysreptor/designs/annixion-influence.json" && echo 0 || echo 1)" \
  "the influence design carries DISARM and its mapping appendix" \
  "no disarm_techniques field or no appendix"
report "$(grep -q 'attack_techniques' "$ROOT/assets/sysreptor/designs/annixion-engagement.json" && echo 0 || echo 1)" \
  "the engagement design carries ATT&CK" "no attack_techniques field"
report "$(grep -q 'attack_techniques' "$ROOT/assets/sysreptor/designs/annixion-osint.json" && echo 0 || echo 1)" \
  "the OSINT design carries the pre-intrusion ATT&CK tactics" "no attack_techniques field"

owntitles=$(grep -ho '"title": "[^"]*"' "$TMP"/own/*.json | sort -u)
for want in "Tailgating" "Badge" "Phishing" "SQL Injection" "Kerberoast" "Cloud Storage" \
            "Subdomain Takeover" "Look-Alike" "QR Code" "Key and Lock" "Disposal" "Insider"; do
  report "$(grep -qi "$want" <<<"$owntitles" && echo 0 || echo 1)" \
    "the library covers: $want" "no template title matches '$want'"
done

# The tri-split the browser profiles already use. A template with none of
# these is uncategorised in a UI that filters by tag.
untagged=0
for f in "$TMP"/own/*.json; do
  grep -qE '"(red|puppet|osint|process)"' "$f" || untagged=$((untagged + 1))
done
report "$([ "$untagged" -eq 0 ] && echo 0 || echo 1)" \
  "every template carries a discipline tag" "$untagged are untagged"
report "$(grep -lq '"puppet"' "$TMP"/own/*.json && echo 0 || echo 1)" \
  "the social-engineering findings are tagged puppet" "no puppet-tagged template"

# Duplicate titles are the complaint this guards against: two templates for
# one finding means the operator picks between them in the UI every time.
dupes=$(grep -ho '"title": "[^"]*"' "$TMP"/own/*.json | sort | uniq -d)
report "$([ -z "$dupes" ] && echo 0 || echo 1)" \
  "no two templates share a title" "duplicated: $(tr '\n' ' ' <<<"$dupes")"

# Deterministic ids: a re-import must update a template, not clone it.
dupids=$(grep -ho '"id": "[^"]*"' "$TMP"/own/*.json | sort | uniq -d | wc -l)
report "$([ "$dupids" -eq 0 ] && echo 0 || echo 1)" \
  "template ids are unique" "$dupids ids appear twice"

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
for pack in annixion htb offsec demo; do
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

# ── The distribution's own report designs ──────────────────────────────────
# A design is a field definition plus a Vue template; both fail at render
# time, in front of a client, so what is asserted here is that the two agree
# and that the mark really is the one catalog/logo.nix draws.
mkdir -p "$TMP/designs"
tar xzf "$packs/design-annixion.tar.gz" -C "$TMP/designs" 2>/dev/null
chmod -R u+w "$TMP/designs"
ndesign=$(find "$TMP/designs" -maxdepth 1 -name '*.json' | wc -l)
report "$([ "$ndesign" -eq 3 ] && echo 0 || echo 1)" \
  "all three AnNIXion designs are packed" "found $ndesign"

for d in engagement osint influence; do
  f="$TMP/designs/annixion-$d.json"
  report "$([ -f "$f" ] && echo 0 || echo 1)" "the $d design is present" "no annixion-$d.json"
  [ -f "$f" ] || continue
  out=$(python3 -c "
import json, re, sys
d = json.load(open(sys.argv[1]))
t = d['report_template']
declared = {fl['id'] for s in d['report_sections'] for fl in s['fields']}
used = set(re.findall(r'report\.([a-z_]+)', t))
fdeclared = {fl['id'] for fl in d['finding_fields']} | {'id'}
fused = set(re.findall(r'finding\.([a-z_]+)', t))
print('fields=%d sections=%d missing=%s fmissing=%s placeholder=%s svg=%d'
      % (sum(len(s['fields']) for s in d['report_sections']), len(d['report_sections']),
         ','.join(sorted(used - declared)) or 'none',
         ','.join(sorted(fused - fdeclared)) or 'none',
         '@LOGO_SVG@' in t, t.count('<svg')))
" "$f" 2>/dev/null)
  report "$(grep -q 'missing=none' <<<"$out" && echo 0 || echo 1)" \
    "the $d template references only declared fields" "$out"
  report "$(grep -q 'fmissing=none' <<<"$out" && echo 0 || echo 1)" \
    "and only declared finding fields" "$out"
  report "$(grep -q 'placeholder=False' <<<"$out" && echo 0 || echo 1)" \
    "the $d design has its logo substituted" "$out"
  report "$(grep -q 'svg=2' <<<"$out" && echo 0 || echo 1)" \
    "the $d design carries the mark on cover and header" "$out"
  # The summary is the page that gets read; a severity chart belongs on it.
  report "$(python3 -c "
import json, sys
t = json.load(open(sys.argv[1]))['report_template']
sys.exit(0 if '<chart' in t and 'chart-figure' in t else 1)
" "$f" 2>/dev/null && echo 0 || echo 1)" \
    "the $d design charts its severities" "no chart in the summary"
  # The mark goes inside a JSON string; a double quote in it breaks the file.
  report "$(python3 -c "
import json, re, sys
t = json.load(open(sys.argv[1]))['report_template']
sys.exit(0 if '\"' not in re.search(r'<svg.*?</svg>', t, re.S).group(0) else 1)
" "$f" 2>/dev/null && echo 0 || echo 1)" \
    "the $d inline mark carries no double quotes" "it would break the JSON"
done

# The engagement design is the one that has to cover a whole engagement.
engsections=$(python3 -c "
import json, sys
print(' '.join(s['id'] for s in json.load(open(sys.argv[1]))['report_sections']))
" "$ROOT/assets/sysreptor/designs/annixion-engagement.json" 2>/dev/null)
missing_sections=""
for want in recon social physical attack_path detection remediation; do
  grep -qw "$want" <<<"$engsections" || missing_sections="$missing_sections $want"
done
report "$([ -z "$missing_sections" ] && echo 0 || echo 1)" \
  "the engagement design covers every phase" "no section for:$missing_sections"

osintsections=$(python3 -c "
import json, sys
print(' '.join(s['id'] for s in json.load(open(sys.argv[1]))['report_sections']))
" "$ROOT/assets/sysreptor/designs/annixion-osint.json" 2>/dev/null)
missing_sections=""
for want in tasking methodology subject footprint exposure people assessment; do
  grep -qw "$want" <<<"$osintsections" || missing_sections="$missing_sections $want"
done
report "$([ -z "$missing_sections" ] && echo 0 || echo 1)" \
  "the OSINT design is an intelligence product" "no section for:$missing_sections"

# The influence design makes claims about who is behind coordinated activity.
# Competing hypotheses and the persona record are not decoration: without the
# first it is an accusation, and without the second the collection cannot be
# defended.
inflsections=$(python3 -c "
import json, sys
print(' '.join(s['id'] for s in json.load(open(sys.argv[1]))['report_sections']))
" "$ROOT/assets/sysreptor/designs/annixion-influence.json" 2>/dev/null)
missing_sections=""
for want in tasking methodology campaign network reach attribution response; do
  grep -qw "$want" <<<"$inflsections" || missing_sections="$missing_sections $want"
done
report "$([ -z "$missing_sections" ] && echo 0 || echo 1)" \
  "the influence design covers the campaign end to end" "no section for:$missing_sections"

inflfields=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
print(' '.join(f['id'] for s in d['report_sections'] for f in s['fields']))
" "$ROOT/assets/sysreptor/designs/annixion-influence.json" 2>/dev/null)
for want in hypotheses alternative_explanation attribution_caveats personas persona_opsec legal_basis; do
  report "$(grep -qw "$want" <<<"$inflfields" && echo 0 || echo 1)" \
    "the influence design records: $want" "no field '$want'"
done

# ── Plugins and the theme ──────────────────────────────────────────────────
conf_plugins=$(read_conf ANNIXION_SYSREPTOR_PLUGINS)
missing_plugins=""
for plugin in cyberchef checkthehash graphqlvoyager customizetheme markdownexport projectnumber; do
  grep -q "$plugin" <<<"$conf_plugins" || missing_plugins="$missing_plugins $plugin"
done
report "$([ -z "$missing_plugins" ] && echo 0 || echo 1)" \
  "every community-edition plugin is enabled by default" "not enabled:$missing_plugins"
# Professional-only plugins would be enabled but inert, and demoplugin is a
# demonstration of the plugin system rather than a tool.
report "$(grep -q demoplugin <<<"$conf_plugins" && echo 1 || echo 0)" \
  "the demo plugin stays out" "demoplugin is enabled"

theme_file=$(read_conf ANNIXION_SYSREPTOR_THEME_FILE)
report "$([ -n "$theme_file" ] && [ -f "$theme_file" ] && echo 0 || echo 1)" \
  "the theme is built and referenced" "theme file is ${theme_file:-<unset>}"
if [ -f "$theme_file" ]; then
  report "$(python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$theme_file" 2>/dev/null && echo 0 || echo 1)" \
    "the theme is valid JSON" "the plugin would reject it"
  ramp=$(python3 -c "
import json, sys
c = json.load(open(sys.argv[1]))['all']['colors']
print(' '.join(c['risk-' + k] for k in ('critical', 'high', 'medium', 'low', 'info')))
" "$theme_file" 2>/dev/null)
  report "$([ "${ramp%% *}" = "#FF0033" ] && echo 0 || echo 1)" \
    "critical is the signature red" "ramp is ${ramp:-<unset>}"
  # High is orange everywhere a CVSS score is read. A house colour here would
  # be read as a different severity, which is the one thing a ramp must not do.
  high=$(cut -d' ' -f2 <<<"$ramp")
  report "$([ "$high" = "#FF9300" ] && echo 0 || echo 1)" \
    "high keeps the conventional orange" "high is ${high:-<unset>}"
  # The logo travels as a data URI, so it must decode to the real mark.
  logo=$(python3 -c "
import base64, json, sys
d = json.load(open(sys.argv[1]))
u = d['all']['variables']['header-logo-url']
sys.stdout.write(base64.b64decode(u.split(',', 1)[1]).decode())
" "$theme_file" 2>/dev/null)
  report "$(grep -q '<svg' <<<"$logo" && echo 0 || echo 1)" \
    "the header logo decodes to an SVG" "decoded: $(head -c 80 <<<"$logo")"
  marksrc=$(grep -o 'd="[^"]*"' "$ROOT/catalog/logo.nix" | head -1)
  report "$(grep -qF "${marksrc#d=}" <<<"$logo" && echo 0 || echo 1)" \
    "and it is the launcher's own mark, not a copy" \
    "catalog/logo.nix and the theme logo have diverged"
fi

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
ANNIXION_SYSREPTOR_FINDING_TEMPLATES=""
CONF
# Appended rather than inlined: the block above is quoted, and the theme path
# is whatever this build produced.
{
  echo 'ANNIXION_SYSREPTOR_PLUGINS="cyberchef,customizetheme"'
  [ -n "$theme_file" ] && echo "ANNIXION_SYSREPTOR_THEME_FILE=\"$theme_file\""
} >>"$conf_home/sysreptor.conf"

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

# The plugin list and the theme are configuration too, so they are synced
# into app.env beside ALLOWED_HOSTS — and must not disturb the keys.
report "$(grep -q '^ENABLED_PLUGINS=' "$confenv" && echo 0 || echo 1)" \
  "the plugin list reaches app.env" "no ENABLED_PLUGINS line"
report "$(grep -q "^PLUGIN_CUSTOMIZETHEME_CONFIG='{" "$confenv" && echo 0 || echo 1)" \
  "the theme reaches app.env as single-quoted JSON" \
  "line is: $(grep -o '^PLUGIN_CUSTOMIZETHEME_CONFIG=.\{0,20\}' "$confenv")"
report "$([ "$(grep -c '^ENABLED_PLUGINS=' "$confenv")" -eq 1 ] && echo 0 || echo 1)" \
  "and the sync does not duplicate it on a second run" \
  "ENABLED_PLUGINS appears $(grep -c '^ENABLED_PLUGINS=' "$confenv") times"

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
seen=$(grep -c '^design:' "$imp/instance-names" 2>/dev/null || echo 0)
report "$([ "${seen:-0}" -ge 9 ] && echo 0 || echo 1)" \
  "every design in the pack reaches the instance" "the instance holds ${seen:-0}"
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

# The failure this reconciliation exists for: a pack that gains a design after
# the instance has already imported it. The old gate recorded the pack as done
# and the new design could never arrive. Drop one name from what the instance
# reports and the next run must fetch exactly that one back.
dropped=$(grep '^design:' "$imp/instance-names" | head -1)
grep -vxF "$dropped" "$imp/instance-names" >"$imp/instance-names.tmp"
mv "$imp/instance-names.tmp" "$imp/instance-names"
drive "$imp" designs >/dev/null
imports=$(grep -c 'importdemodata --type=design' "$imp/docker.log")
report "$([ "${imports:-0}" -eq 2 ] && echo 0 || echo 1)" \
  "a design missing from the instance is imported on the next run" \
  "importdemodata ran ${imports:-0} time(s) in total"
report "$(grep -qxF "$dropped" "$imp/instance-names" && echo 0 || echo 1)" \
  "and it is the one that was missing" "'$dropped' did not come back"
back=$(grep -c "^$dropped\$" "$imp/instance-names")
report "$([ "${back:-0}" -eq 1 ] && echo 0 || echo 1)" \
  "without duplicating the designs already there" \
  "'$dropped' is present ${back:-0} time(s)"

# ── The declared login is created once ─────────────────────────────────────
# Re-applying it on every start would silently revert a password changed in
# the UI, which is the only place it can be changed.
# shellcheck disable=SC2016 # a hash, not an expansion — the $ must stay literal
login_hash='pbkdf2_sha256$600000$testsalt$dGVzdGhhc2g='
logins=$(grep -c 'BOOTSTRAP_USERNAME' "$imp/docker.log")
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

proj="$TMP/h5"
mkdir -p "$proj"
cat >"$proj/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS="htb demo"
ANNIXION_SYSREPTOR_DEMO_PROJECTS="yes"
ANNIXION_SYSREPTOR_FINDING_TEMPLATES="annixion"
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
configured_libs=$(read_conf ANNIXION_SYSREPTOR_FINDING_TEMPLATES)
report "$([ "$configured_libs" = "annixion" ] && echo 0 || echo 1)" \
  "exactly one template library is configured" \
  "config says '$configured_libs' — two libraries means every shared finding appears twice"

off="$TMP/h7"
mkdir -p "$off"
cat >"$off/sysreptor.conf" <<CONF
ANNIXION_SYSREPTOR_PORT="$hport"
ANNIXION_SYSREPTOR_DESIGNS="htb"
ANNIXION_SYSREPTOR_FINDING_TEMPLATES=""
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
