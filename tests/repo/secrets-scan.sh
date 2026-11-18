#!/usr/bin/env bash
# Fixture test for scan-secrets.sh. Driven against a stub `trufflehog` that
# logs the arguments it received and exits with a configurable code — no
# network, no real scan, so this proves the wrapper builds the right command
# rather than trufflehog's own detection (which needs live API verification
# the test environment cannot do).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/scripts/scan-secrets.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fails=0

stub="$TMP/stub"
mkdir -p "$stub"
cat >"$stub/trufflehog" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$TRUFFLEHOG_STUB_LOG"
exit "${TRUFFLEHOG_STUB_EXIT:-0}"
STUB
chmod +x "$stub/trufflehog"

drive() {
  PATH="$stub:$PATH" TRUFFLEHOG_STUB_LOG="$TMP/args" TRUFFLEHOG_STUB_EXIT="${STUB_EXIT:-0}" \
    "$SCRIPT" "$@"
}

report() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" -eq 0 ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s: %s\n' "$name" "$detail"
    fails=$((fails + 1))
  fi
}

# ── Usage errors ────────────────────────────────────────────────────────
drive >/dev/null 2>&1
report "$([ $? -eq 2 ] && echo 0 || echo 1)" "no arguments is a usage error" "exit $?"

drive --since >/dev/null 2>&1
report "$([ $? -eq 2 ] && echo 0 || echo 1)" "--since with no commit is a usage error" "exit $?"

drive --since abc123 extra >/dev/null 2>&1
report "$([ $? -eq 2 ] && echo 0 || echo 1)" "--since with a trailing argument is a usage error" "exit $?"

drive --full extra >/dev/null 2>&1
report "$([ $? -eq 2 ] && echo 0 || echo 1)" "--full with a trailing argument is a usage error" "exit $?"

drive --bogus >/dev/null 2>&1
report "$([ $? -eq 2 ] && echo 0 || echo 1)" "an unknown flag is a usage error" "exit $?"

# ── A PR's own commits, since the base ───────────────────────────────────
drive --since abc123 >/dev/null 2>&1
args=$(cat "$TMP/args")
case "$args" in
  *"git file://$ROOT"*"--results=verified"*"--fail"*"--since-commit=abc123"*) ok=0 ;;
  *) ok=1 ;;
esac
report "$ok" "--since scans only the commits after the given one" "got: $args"

# ── A release gate's full history ─────────────────────────────────────────
drive --full >/dev/null 2>&1
args=$(cat "$TMP/args")
case "$args" in
  *"--since-commit"*) ok=1 ;;
  *"git file://$ROOT"*"--results=verified"*"--fail"*) ok=0 ;;
  *) ok=1 ;;
esac
report "$ok" "--full carries no --since-commit" "got: $args"

# ── A verified finding fails the run, same as CI needs it to ─────────────
STUB_EXIT=183 drive --full >/dev/null 2>&1
report "$([ $? -eq 183 ] && echo 0 || echo 1)" "trufflehog's exit code is propagated" "exit $?"

echo
if [ "$fails" -eq 0 ]; then
  echo "secrets-scan: all tests passed"
else
  echo "secrets-scan: $fails test(s) failed"
fi
exit "$fails"
