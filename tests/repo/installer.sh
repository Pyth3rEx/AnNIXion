#!/usr/bin/env bash
# Drives the real annixion-install with every destructive or interactive
# command stubbed on PATH — parted, mkfs.*, mount, nixos-install,
# nixos-enter, reboot, gum, mkpasswd, python3, and nix itself (no real
# closure eval: nix is a log-and-answer stub, not the genuine evaluator,
# the same way tests/repo/cve-report.sh stands in for it). Asserts the
# device sequence, the --user-config branches, the EFI guard and the
# reboot exit-code fix. No disk, no VM, no network — git stays real,
# cloning from a throwaway local repo standing in for AnNIXion upstream.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/annixion-install"
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

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/log"
mkdir -p "$TMP/bin"

mkstub() {
  local name="$1"
  cat >"$TMP/bin/$name" <<HEADER
#!/usr/bin/env bash
printf '%s %s\n' "$name" "\$*" >>"$LOG"
HEADER
  cat >>"$TMP/bin/$name"
  chmod +x "$TMP/bin/$name"
}

mkstub parted <<'BODY'
exit 0
BODY

mkstub mkfs.fat <<'BODY'
exit 0
BODY

mkstub mkfs.ext4 <<'BODY'
exit 0
BODY

mkstub udevadm <<'BODY'
exit 0
BODY

mkstub mount <<'BODY'
exit 0
BODY

mkstub nixos-install <<'BODY'
exit 0
BODY

mkstub nixos-enter <<'BODY'
exit 0
BODY

mkstub reboot <<'BODY'
exit 0
BODY

mkstub lsblk <<'BODY'
case "$*" in
  *-dno\ SIZE*) echo "20G" ;;
  *) echo "fakedisk 20G FakeDisk" ;;
esac
BODY

mkstub timedatectl <<'BODY'
if [ "${1:-}" = "list-timezones" ]; then
  echo "UTC"
  echo "America/New_York"
fi
exit 0
BODY

mkstub localectl <<'BODY'
if [ "${1:-}" = "list-keymaps" ]; then
  echo "us"
  echo "fr"
fi
exit 0
BODY

# nixos-generate-config normally writes hardware-configuration.nix into
# --dir; the real script immediately `git add -f`s that file, so the stub
# has to leave something there too.
mkstub nixos-generate-config <<'BODY'
dir="" prev=""
for a in "$@"; do
  [ "$prev" = "--dir" ] && dir="$a"
  prev="$a"
done
[ -n "$dir" ] && : >"$dir/hardware-configuration.nix"
exit 0
BODY

mkstub mkpasswd <<'BODY'
cat >/dev/null
echo '$6$stub$stubhashstubhashstubhash'
BODY

mkstub python3 <<'BODY'
if [ "${1:-}" = "-c" ]; then
  echo 'pbkdf2_sha256$600000$stub$stubhash'
else
  exit 0
fi
BODY

# gum: answers every prompt with its own suggested default (the --value or
# --selected the real wizard already pre-filled), or $TEST_CHOOSE_ANSWER /
# $TEST_CONFIRM_SKIP for the ones that have no default to echo back.
mkstub gum <<'BODY'
case "$1" in
  style) exit 0 ;;
  # The real gum spin hides the wrapped command behind a spinner; the stub
  # just has to still run it, or everything after "--" (parted, mkfs, the
  # whole install) silently never happens.
  spin)
    shift
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
    shift
    "$@"
    exit $?
    ;;
  # filter has a real upstream pipe (timedatectl/localectl) that must be
  # drained, or it races the stub exiting and SIGPIPEs intermittently.
  # input never does — it inherits the script's own stdin, mid-prompts.
  filter) cat >/dev/null ;;
esac
case "$1" in
  input | filter)
    prev=""
    for a in "$@"; do
      [ "$prev" = "--value" ] && { echo "$a"; exit 0; }
      prev="$a"
    done
    for a in "$@"; do [ "$a" = "--password" ] && { echo "${TEST_PW:-TestPassw0rd}"; exit 0; }; done
    echo ""
    ;;
  choose)
    prev="" selected="" saw_selected=0
    for a in "$@"; do
      if [ "$prev" = "--selected" ]; then
        selected="$a"
        saw_selected=1
      fi
      prev="$a"
    done
    if [ "$saw_selected" = "1" ]; then
      [ -n "$selected" ] && echo "$selected" | tr ',' '\n'
    else
      echo "${TEST_CHOOSE_ANSWER:-Continue without it}"
    fi
    ;;
  confirm)
    for a in "$@"; do
      [ "$a" = "--default=true" ] && exit 0
      [ "$a" = "--default=false" ] && exit 1
    done
    [ "${TEST_CONFIRM_SKIP:-false}" = "true" ] && exit 0 || exit 1
    ;;
esac
BODY

# nix: a log-and-answer stub, not the evaluator — this test is about
# annixion-install's control flow, not nix's own correctness (that is
# tests/shell/firefox-profiles.sh's and tests/shell/sysreptor.sh's job).
# "broken" is simulated by a BROKEN_MARKER left in the staged config.
mkstub nix <<'BODY'
if [ "$1" = "eval" ]; then
  flakeref=""
  for a in "$@"; do flakeref="$a"; done
  dir="${flakeref%%#*}"
  if [ -f "$dir/user/configuration.nix" ] && grep -q BROKEN_MARKER "$dir/user/configuration.nix" 2>/dev/null; then
    echo "error: BROKEN_MARKER (stub)" >&2
    exit 1
  fi
  case "$*" in
    *--json*)
      echo '{"hostname":"stub","timezone":"UTC","keymap":"us","compositing":false,"username":"operator","sysreptorUser":"operator","profiles":{"redteam":true,"osint":true,"puppet":true,"untrusted":true}}'
      ;;
    # read_username's query, distinct from eval_flake's .drvPath one below —
    # annixion-install builds /home/$INSTALL_USERNAME/... paths straight
    # from this, so a wrong answer here breaks path assertions, not just
    # this stub's own output.
    *users.users.operator.name*) echo "operator" ;;
    *) echo "/nix/store/fakedrvpath" ;;
  esac
fi
exit 0
BODY

# ── A throwaway repo standing in for AnNIXion upstream ──────────────────────
UPSTREAM="$TMP/upstream"
mkdir -p "$UPSTREAM/user"
printf '0.5.0\n' >"$UPSTREAM/VERSION"
cat >"$UPSTREAM/user/configuration.nix" <<'NIX'
{ lib, ... }:
{ }
NIX
cat >"$UPSTREAM/user/home.nix" <<'NIX'
{ lib, ... }:
{ imports = [ ]; }
NIX
(cd "$UPSTREAM" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init)

run() {
  : >"$LOG"
  PATH="$TMP/bin:$PATH" \
    ANNIXION_TEST_SKIP_SUDO=1 \
    ANNIXION_TEST_EFI_DIR="${TEST_EFI_DIR:-$TMP}" \
    ANNIXION_TEST_MNT="$TMP/mnt" \
    ANNIXION_TEST_SKIP_DISK_CHECK=1 \
    ANNIXION_TEST_REPO_URL="$UPSTREAM" \
    TEST_CHOOSE_ANSWER="${TEST_CHOOSE_ANSWER:-}" \
    TEST_CONFIRM_SKIP="${TEST_CONFIRM_SKIP:-}" \
    bash "$SCRIPT" "$@"
}

# ── --help ───────────────────────────────────────────────────────────────
out=$(bash "$SCRIPT" --help 2>&1)
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "--help exits 0" "exit $rc"
report "$(grep -q -- '--user-config' <<<"$out" && echo 0 || echo 1)" \
  "--help documents --user-config" "$out"

# ── EFI guard fires before anything else ────────────────────────────────────
rm -rf "${TMP:?}/mnt"
TEST_EFI_DIR="$TMP/no-such-dir" run </dev/null >"$TMP/stdout.efi" 2>&1
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" "legacy BIOS is refused" "exit $rc"
report "$([ ! -s "$LOG" ] && echo 0 || echo 1)" \
  "...before any command runs" "log: $(cat "$LOG" 2>/dev/null)"

# ── Full default path: wizard runs, reboot declined (the exit-code fix) ────
rm -rf "${TMP:?}/mnt"
printf 'fakedisk\nyes\nn\n' | run >"$TMP/stdout.a" 2>&1
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "declining the reboot still exits 0" "exit $rc; $(tail -5 "$TMP/stdout.a")"
report "$(grep -q '^parted .*fakedisk' "$LOG" && echo 0 || echo 1)" \
  "partitions the chosen disk" "log: $(cat "$LOG")"
fat_line=$(grep -n '^mkfs\.fat ' "$LOG" | head -1 | cut -d: -f1)
ext_line=$(grep -n '^mkfs\.ext4 ' "$LOG" | head -1 | cut -d: -f1)
seq_ok=1
[ -n "$fat_line" ] && [ -n "$ext_line" ] && [ "$fat_line" -lt "$ext_line" ] && seq_ok=0
report "$seq_ok" "formats ESP before root" "log: $(grep '^mkfs' "$LOG")"
report "$(grep -q '^nixos-install ' "$LOG" && echo 0 || echo 1)" "runs nixos-install" "log: $(cat "$LOG")"
report "$(grep -q '^nixos-enter ' "$LOG" && echo 0 || echo 1)" "fixes ownership" "log: $(cat "$LOG")"
report "$(grep -q '^reboot ' "$LOG" && echo 1 || echo 0)" "does not reboot when declined" "log: $(cat "$LOG")"
report "$(grep -q '^gum input --header Hostname' "$LOG" && echo 0 || echo 1)" "the wizard ran with no --user-config" "log: $(cat "$LOG")"
cfg="$TMP/mnt/home/operator/.dotfiles/user/configuration.nix"
report "$([ -f "$cfg" ] && grep -q 'stub' "$cfg" && echo 0 || echo 1)" \
  "the wizard's answers reached user/configuration.nix" "$([ -f "$cfg" ] && cat "$cfg" || echo "<missing>")"

# ── Reboot accepted ─────────────────────────────────────────────────────────
rm -rf "${TMP:?}/mnt"
printf 'fakedisk\nyes\ny\n' | run >"$TMP/stdout.a2" 2>&1
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "accepting the reboot also exits 0" "exit $rc"
report "$(grep -q '^reboot ' "$LOG" && echo 0 || echo 1)" "...and reboot actually runs" "log: $(cat "$LOG")"

# ── --user-config: fresh + skip-wizard ──────────────────────────────────────
FRESH="$TMP/fresh"
mkdir -p "$FRESH/user"
printf '0.5.0\nskip\n' >"$FRESH/user/.annixion-version"
cat >"$FRESH/user/configuration.nix" <<'NIX'
{ lib, ... }:
{ networking.hostName = "FIXTURE-SKIP"; }
NIX
rm -rf "${TMP:?}/mnt"
printf 'fakedisk\nyes\nn\n' | run --user-config "$FRESH" >"$TMP/stdout.c" 2>&1
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "a fresh, skip-flagged config installs cleanly" "exit $rc; $(tail -5 "$TMP/stdout.c")"
report "$(grep -q '^gum input --header Hostname' "$LOG" && echo 1 || echo 0)" \
  "...and skips the wizard entirely" "log: $(cat "$LOG")"
cfg="$TMP/mnt/home/operator/.dotfiles/user/configuration.nix"
report "$([ -f "$cfg" ] && grep -q FIXTURE-SKIP "$cfg" && echo 0 || echo 1)" \
  "...keeping the provided hostname" "$([ -f "$cfg" ] && cat "$cfg" || echo "<missing>")"

# ── --user-config: stale version re-runs the wizard despite skip=skip ───────
STALE="$TMP/stale"
mkdir -p "$STALE/user"
printf '0.1.0\nskip\n' >"$STALE/user/.annixion-version"
cat >"$STALE/user/configuration.nix" <<'NIX'
{ lib, ... }:
{ networking.hostName = "FIXTURE-STALE"; }
NIX
rm -rf "${TMP:?}/mnt"
printf 'fakedisk\nyes\nn\n' | run --user-config "$STALE" >"$TMP/stdout.d" 2>&1
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "a stale config still installs" "exit $rc; $(tail -5 "$TMP/stdout.d")"
report "$(grep -q '^gum input --header Hostname' "$LOG" && echo 0 || echo 1)" \
  "...but the wizard runs anyway" "log: $(cat "$LOG")"

# ── --user-config: broken config, continue without it ───────────────────────
BROKEN="$TMP/broken"
mkdir -p "$BROKEN/user"
cat >"$BROKEN/user/configuration.nix" <<'NIX'
{ lib, ... }:
{ BROKEN_MARKER = true; }
NIX
rm -rf "${TMP:?}/mnt"
TEST_CHOOSE_ANSWER="Continue without it"
printf 'fakedisk\nyes\nn\n' | run --user-config "$BROKEN" >"$TMP/stdout.e" 2>&1
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "continuing past a broken config still installs" "exit $rc; $(tail -8 "$TMP/stdout.e")"
report "$(grep -q 'does not evaluate' "$TMP/stdout.e" && echo 0 || echo 1)" \
  "...having reported why it was rejected" "$(cat "$TMP/stdout.e")"
report "$(grep -q '^gum input --header Hostname' "$LOG" && echo 0 || echo 1)" \
  "...and fallen back to the wizard" "log: $(cat "$LOG")"

# ── --user-config: broken config, abort ──────────────────────────────────
rm -rf "${TMP:?}/mnt"
TEST_CHOOSE_ANSWER="Abort"
printf 'fakedisk\nyes\nn\n' | run --user-config "$BROKEN" >"$TMP/stdout.f" 2>&1
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" "aborting on a broken config exits nonzero" "exit $rc"
report "$(grep -q '^parted ' "$LOG" && echo 1 || echo 0)" \
  "...before the disk is ever touched" "log: $(cat "$LOG")"

echo
if [ "$fails" -eq 0 ]; then
  echo "installer: all tests passed"
else
  echo "installer: $fails test(s) failed"
fi
exit "$fails"
