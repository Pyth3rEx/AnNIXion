#!/usr/bin/env bash
# tlog-engagement is the opt-in front door onto a vendored, hand-packaged tlog
# — nixpkgs doesn't have it yet (NixOS/nixpkgs#571777 is still open against
# master, and the pin here is nixos-26.05 regardless), so there is no
# fallback if the derivation stops building.
#
# The failure that matters most: --log-input defaults to off, so a password
# typed mid-session is never written to disk unless an operator deliberately
# turns it on. The rest is the wrapper's own contract — start refuses to
# nest, push finds the right recording and hands reptor the right things,
# and the two "it ships with" dependencies (tlog-rec/tlog-play, reptor) fail
# by name rather than with a raw error when they are missing.
#
# tlog-rec/tlog-play locate their own /etc/tlog config by inspecting
# argv[0]'s literal text, not their real location — which is also why there
# is no real /etc/tlog to give them here. A stand-in build-tree layout
# (binaries under a `.libs` directory, config files beside it) is built from
# the real output and put ahead of it on PATH, the same trick the package's
# own installCheckPhase uses. No docker, no network, no VM.
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

# ── The package, as built ───────────────────────────────────────────────
# Through the flake, not <nixpkgs>: a CI runner sets no channel. Matched by
# prefix so a version bump does not have to be mirrored here.
err="$TMP/err"
drv=$(nix eval --raw "$CFG.environment.systemPackages" --apply \
  'ps: (builtins.head (builtins.filter (p: builtins.match "tlog-engagement-.*" (p.name or "") != null) ps)).drvPath' \
  2>"$err")
out=""
[ -n "$drv" ] && out=$(nix build --no-link --print-out-paths "${drv}^*" 2>>"$err")

if [ -z "$out" ]; then
  printf 'tlog: the package did not build\n%s\n' "$(tail -n 5 "$err")"
  exit 1
fi

bin="$out/bin/tlog-engagement"
for exe in tlog-engagement tlog-rec tlog-play; do
  report "$([ -x "$out/bin/$exe" ] && echo 0 || echo 1)" \
    "$exe is on PATH" "no executable at $out/bin/$exe"
done

help=$("$bin" help 2>&1)
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" "help exits zero" "exit $rc"
missing=""
for cmd in start push list play; do
  grep -q -- "$cmd" <<<"$help" || missing="$missing $cmd"
done
report "$([ -z "$missing" ] && echo 0 || echo 1)" \
  "help names every subcommand" "not documented:$missing"

# ── Preconditions fail as sentences ─────────────────────────────────────
noname=$("$bin" start 2>&1)
report "$(grep -q "needs an engagement name" <<<"$noname" && echo 0 || echo 1)" \
  "start without a name says so" "said: $noname"

noplay=$("$bin" play 2>&1)
report "$(grep -q "needs a recording path" <<<"$noplay" && echo 0 || echo 1)" \
  "play without a path says so" "said: $noplay"

nopush=$(XDG_DATA_HOME="$TMP/no-state" "$bin" push </dev/null 2>&1)
report "$(grep -q "no recording to push" <<<"$nopush" && echo 0 || echo 1)" \
  "push with nothing recorded and no path says so" "said: $nopush"

badopt=$("$bin" start somename --bogus 2>&1)
report "$(grep -q "unknown option" <<<"$badopt" && echo 0 || echo 1)" \
  "start rejects an unknown option" "said: $badopt"

nested=$(ANNIXION_TLOG_ENGAGEMENT=other "$bin" start somename 2>&1)
report "$(grep -q "already recording 'other'" <<<"$nested" && echo 0 || echo 1)" \
  "start refuses to nest inside an already-recording shell" "said: $nested"

# ── A stand-in build-tree layout, so tlog-rec/tlog-play find a config ───
# Mirrors the package's own installCheckPhase: binaries copied (not
# symlinked — the lookup uses realpath) under a `.libs` directory, with the
# local and default conf files one level up from it.
stub="$TMP/stub"
mkdir -p "$stub/.libs"
cp "$out/bin/tlog-rec" "$out/bin/tlog-play" "$stub/.libs/"
cp "$out"/etc/tlog/tlog-{rec,play}.conf \
  "$out"/share/tlog/tlog-{rec,play}.default.conf "$stub/"
stubpath="$stub/.libs:$PATH"

# No stub on PATH yet at this point — the dev shell carries no tlog-play of
# its own, so this is already "missing" without having to fake it further.
noconf=$("$bin" play "$TMP/nope" 2>&1)
report "$(grep -q "not found on PATH" <<<"$noconf" && echo 0 || echo 1)" \
  "a missing tlog-play is named as such" "said: $noconf"

# ── A real record/replay round trip, through the wrapper itself ────────
home1="$TMP/h1"
xdg1="$home1/.local/share"
mkdir -p "$xdg1"
marker="marker-$$-output"
start_out=$(PATH="$stubpath" XDG_DATA_HOME="$xdg1" \
  "$bin" start acme-2026 -- bash -c "echo $marker" 2>&1)
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "start records the given command and exits with its status" \
  "exit $rc, said: $start_out"

rec1=$(find "$xdg1" -name '*.tlog.json' 2>/dev/null | head -1)
report "$([ -n "$rec1" ] && [ -f "$rec1" ] && echo 0 || echo 1)" \
  "a recording lands under the engagement's own directory" \
  "nothing under $xdg1"
report "$(grep -qF "$marker" "${rec1:-/dev/null}" && echo 0 || echo 1)" \
  "and it carries the command's real output" "recording: $(cat "${rec1:-/dev/null}" 2>/dev/null)"
report "$(grep -qF '/acme-2026/' <<<"${rec1:-}" && echo 0 || echo 1)" \
  "filed under the engagement name it was started with" "path: ${rec1:-<none>}"

listed=$(PATH="$stubpath" XDG_DATA_HOME="$xdg1" "$bin" list 2>&1)
report "$(grep -qF "$rec1" <<<"$listed" && echo 0 || echo 1)" \
  "list surfaces the recording" "listed: $listed"
listed_named=$(PATH="$stubpath" XDG_DATA_HOME="$xdg1" "$bin" list acme-2026 2>&1)
report "$(grep -qF "$rec1" <<<"$listed_named" && echo 0 || echo 1)" \
  "and list scoped to its engagement name finds it too" "listed: $listed_named"
listed_other=$(PATH="$stubpath" XDG_DATA_HOME="$xdg1" "$bin" list no-such-engagement 2>&1)
report "$([ -z "$listed_other" ] && echo 0 || echo 1)" \
  "a different engagement name lists nothing" "listed: $listed_other"

# ── The one check that matters most: --log-input is off by default ──────
# A password typed mid-session must never reach disk unless an operator
# deliberately asks for it — tlog's "in_txt" field is the raw keystroke
# stream, independent of whatever the session happened to echo back.
secret="S3cr3t-$$-value"
home2="$TMP/h2"
xdg2="$home2/.local/share"
mkdir -p "$xdg2"
printf '%s\n' "$secret" | PATH="$stubpath" XDG_DATA_HOME="$xdg2" \
  "$bin" start eng-noinput -- bash -c 'read -r x' >/dev/null 2>&1
rec_noinput=$(find "$xdg2" -name '*.tlog.json' 2>/dev/null | head -1)
report "$([ -n "$rec_noinput" ] && ! grep -qF "$secret" "$rec_noinput" && echo 0 || echo 1)" \
  "input is not captured by default" \
  "the secret appears in: $(cat "${rec_noinput:-/dev/null}" 2>/dev/null)"

home3="$TMP/h3"
xdg3="$home3/.local/share"
mkdir -p "$xdg3"
printf '%s\n' "$secret" | PATH="$stubpath" XDG_DATA_HOME="$xdg3" \
  "$bin" start eng-withinput --log-input -- bash -c 'read -r x' >/dev/null 2>&1
rec_withinput=$(find "$xdg3" -name '*.tlog.json' 2>/dev/null | head -1)
report "$([ -n "$rec_withinput" ] && grep -qF "$secret" "$rec_withinput" && echo 0 || echo 1)" \
  "--log-input is the deliberate opt-in that does capture it" \
  "no match in: $(cat "${rec_withinput:-/dev/null}" 2>/dev/null)"

warned=$(printf '%s\n' "$secret" | PATH="$stubpath" XDG_DATA_HOME="$TMP/h4" \
  "$bin" start eng-warn --log-input -- true 2>&1)
report "$(grep -q "keystrokes, including any password" <<<"$warned" && echo 0 || echo 1)" \
  "turning --log-input on is called out loud, not buried in a flag" "said: $warned"

# ── push: the raw recording and a readable transcript, through reptor ───
stubbin="$TMP/stubbin"
mkdir -p "$stubbin"
reptorlog="$TMP/reptor.log"
reptornote="$TMP/reptor.note"
cat >"$stubbin/reptor" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$REPTOR_STUB_LOG"
[ "$1" = "note" ] && cat >"$REPTOR_STUB_NOTE"
exit 0
STUB
chmod +x "$stubbin/reptor"

: >"$reptorlog"
pushed=$(timeout 20 env PATH="$stub/.libs:$stubbin:$PATH" \
  REPTOR_STUB_LOG="$reptorlog" REPTOR_STUB_NOTE="$reptornote" \
  "$bin" push "$rec1" </dev/null 2>&1)
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "push exits zero and does not hang on a non-interactive stdin" \
  "exit $rc, said: $pushed"
report "$(grep -qxF "file $rec1" "$reptorlog" && echo 0 || echo 1)" \
  "the raw recording is attached as evidence" "reptor saw: $(cat "$reptorlog")"
report "$(grep -qxF "note" "$reptorlog" && echo 0 || echo 1)" \
  "and a transcript is pushed as a note" "reptor saw: $(cat "$reptorlog")"
report "$([ -f "$reptornote" ] && grep -qF "$marker" "$reptornote" && echo 0 || echo 1)" \
  "the transcript carries the session's real output" \
  "transcript: $(cat "$reptornote" 2>/dev/null)"

# push with no argument, from inside a shell that just finished recording —
# ANNIXION_TLOG_FILE is how it finds the right one without being told.
: >"$reptorlog"
implicit=$(timeout 20 env PATH="$stub/.libs:$stubbin:$PATH" \
  REPTOR_STUB_LOG="$reptorlog" REPTOR_STUB_NOTE="$reptornote" \
  ANNIXION_TLOG_FILE="$rec1" "$bin" push </dev/null 2>&1)
report "$(grep -qxF "file $rec1" "$reptorlog" && echo 0 || echo 1)" \
  "push with no argument uses the shell's own just-recorded file" \
  "exit status $?, reptor saw: $(cat "$reptorlog"), said: $implicit"

# A real reptor lives on this very dev box's /run/current-system/sw/bin
# (it is a live AnNIXion install), so plainly appending $PATH would find it
# anyway — the point here is proving the absence case, so the stand-in PATH
# is built from just the two interpreters the #!/usr/bin/env shebang needs
# plus the stub, deliberately leaving the real system closure out.
bashdir=$(dirname "$(command -v bash)")
envdir=$(dirname "$(command -v env)")
noreptor=$(timeout 10 env PATH="$envdir:$bashdir:$stub/.libs" "$bin" push "$rec1" </dev/null 2>&1)
report "$(grep -q "reptor not found" <<<"$noreptor" && echo 0 || echo 1)" \
  "a missing reptor is named as such rather than a raw command-not-found" \
  "said: $noreptor"

# ── The NixOS module: the config tlog refuses to start without ─────────
recconf=$(nix eval --raw "$CFG"'.environment.etc."tlog/tlog-rec.conf".text' 2>/dev/null)
report "$([ "$recconf" = "{}" ] && echo 0 || echo 1)" \
  "tlog-rec.conf exists and is a valid (empty) configuration" "got: $recconf"
playconf=$(nix eval --raw "$CFG"'.environment.etc."tlog/tlog-play.conf".text' 2>/dev/null)
report "$([ "$playconf" = "{}" ] && echo 0 || echo 1)" \
  "tlog-play.conf exists and is a valid (empty) configuration" "got: $playconf"

echo
if [ "$fails" -gt 0 ]; then
  printf 'tlog: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "tlog: opt-in recording stays off until asked for, input stays unlogged until asked for twice"
