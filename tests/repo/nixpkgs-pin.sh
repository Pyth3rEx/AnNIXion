#!/usr/bin/env bash
# Unit-level test for scripts/installer/nixpkgs-pin.sh, in isolation from
# the rest of the installer (tests/repo/installer.sh already drives that
# end to end). Stubs `curl` as a shell function — nixpkgs-pin.sh is sourced
# into this same process, so a function takes priority over any real `curl`
# on PATH without needing a scratch bin/ directory. No network, no `nix`.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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

# shellcheck source=scripts/installer/nixpkgs-pin.sh disable=SC1091
source "$ROOT/scripts/installer/nixpkgs-pin.sh"

# Every well-formed "nixos-XX.YY" branch "exists" (200) unless named in
# $TEST_CURL_404 — same convention as tests/repo/installer.sh's own curl
# stub, kept independent of it since this test never shells out to a
# scratch bin/ directory.
TEST_CURL_FAIL=""
TEST_CURL_404=""
curl() {
  if [[ "$TEST_CURL_FAIL" == "1" ]]; then
    return 28
  fi
  local last=""
  for a in "$@"; do last="$a"; done
  case "$last" in
    *commits\?sha=*)
      echo '[{"sha":"deadbeefcafe"}]'
      ;;
    */branches/nixos-[0-9][0-9].[0-9][0-9])
      local branch="${last##*/branches/}"
      for missing in $TEST_CURL_404; do
        [[ "$branch" == "$missing" ]] && {
          printf '404'
          return 0
        }
      done
      printf '200'
      ;;
    *)
      printf '404'
      ;;
  esac
}

# ── nixpkgs_branch_code ──────────────────────────────────────────────────
code=$(nixpkgs_branch_code "nixos-25.11")
report "$([ "$code" = "200" ] && echo 0 || echo 1)" \
  "an existing branch reports 200" "got: $code"

TEST_CURL_404="nixos-99.99"
code=$(nixpkgs_branch_code "nixos-99.99")
report "$([ "$code" = "404" ] && echo 0 || echo 1)" \
  "a nonexistent branch reports 404" "got: $code"
TEST_CURL_404=""

TEST_CURL_FAIL=1
nixpkgs_branch_code "nixos-25.11" >/dev/null
rc=$?
report "$([ "$rc" -ne 0 ] && echo 0 || echo 1)" \
  "a transport failure returns nonzero, not a fake 404" "exit $rc"
TEST_CURL_FAIL=""

# ── nixpkgs_release_branch_offset ────────────────────────────────────────
latest=$(nixpkgs_release_branch_offset 0)
off1=$(nixpkgs_release_branch_offset 1)
off2=$(nixpkgs_release_branch_offset 2)
report "$([ -n "$latest" ] && [[ "$latest" =~ ^nixos-[0-9]{2}\.(05|11)$ ]] && echo 0 || echo 1)" \
  "offset 0 resolves to a well-formed release branch" "got: $latest"
report "$([ "$off1" != "$latest" ] && [ -n "$off1" ] && echo 0 || echo 1)" \
  "offset 1 resolves to an earlier, different branch" "latest=$latest off1=$off1"
report "$([ "$off2" != "$off1" ] && [ -n "$off2" ] && echo 0 || echo 1)" \
  "offset 2 resolves to a still-earlier branch" "off1=$off1 off2=$off2"

# Forcing the one branch a large offset would need to be missing proves the
# "ran out of history" path fails cleanly rather than returning garbage.
TEST_CURL_404="$off2"
if out=$(nixpkgs_release_branch_offset 2 2>/dev/null); then
  report 1 "an offset reaching past known history fails" "unexpectedly resolved: $out"
else
  report 0 "an offset reaching past known history fails" "-"
fi
TEST_CURL_404=""

# ── nixpkgs_normalize_release ────────────────────────────────────────────
bare=$(nixpkgs_normalize_release "25.11")
prefixed=$(nixpkgs_normalize_release "nixos-25.11")
report "$([ "$bare" = "nixos-25.11" ] && echo 0 || echo 1)" \
  "a bare release string normalizes to a branch name" "got: $bare"
report "$([ "$prefixed" = "nixos-25.11" ] && echo 0 || echo 1)" \
  "an already-prefixed release string is left alone" "got: $prefixed"

TEST_CURL_404="nixos-99.99"
if out=$(nixpkgs_normalize_release "99.99" 2>/dev/null); then
  report 1 "a release that doesn't exist fails to normalize" "unexpectedly resolved: $out"
else
  report 0 "a release that doesn't exist fails to normalize" "-"
fi
TEST_CURL_404=""

TEST_CURL_FAIL=1
trusted=$(nixpkgs_normalize_release "99.99")
report "$([ "$trusted" = "nixos-99.99" ] && echo 0 || echo 1)" \
  "with no network, a release string is trusted rather than blocked" "got: $trusted"
TEST_CURL_FAIL=""

# ── nixpkgs_commit_days_ago ──────────────────────────────────────────────
sha=$(nixpkgs_commit_days_ago 30)
report "$([ "$sha" = "deadbeefcafe" ] && echo 0 || echo 1)" \
  "resolves a commit sha from the branch's history" "got: $sha"

TEST_CURL_FAIL=1
if out=$(nixpkgs_commit_days_ago 30 2>/dev/null); then
  report 1 "fails cleanly with no network" "unexpectedly resolved: $out"
else
  report 0 "fails cleanly with no network" "-"
fi
TEST_CURL_FAIL=""

# ── resolve_nixpkgs_pin dispatch ─────────────────────────────────────────
read -r status ref <<<"$(resolve_nixpkgs_pin default '')"
report "$([ "$status" = "ok" ] && [ -z "$ref" ] && echo 0 || echo 1)" \
  "default mode resolves ok with no ref" "got: '$status' '$ref'"

read -r status ref <<<"$(resolve_nixpkgs_pin latest '')"
report "$([ "$status" = "ok" ] && [[ "$ref" =~ ^nixos- ]] && echo 0 || echo 1)" \
  "latest mode resolves ok with a branch ref" "got: '$status' '$ref'"

read -r status ref <<<"$(resolve_nixpkgs_pin offset 1)"
report "$([ "$status" = "ok" ] && [[ "$ref" =~ ^nixos- ]] && echo 0 || echo 1)" \
  "offset mode resolves ok with a branch ref" "got: '$status' '$ref'"

read -r status ref <<<"$(resolve_nixpkgs_pin specific 25.11)"
report "$([ "$status" = "ok" ] && [ "$ref" = "nixos-25.11" ] && echo 0 || echo 1)" \
  "specific mode resolves ok with the normalized ref" "got: '$status' '$ref'"

read -r status ref <<<"$(resolve_nixpkgs_pin days 30)"
report "$([ "$status" = "ok" ] && [ "$ref" = "deadbeefcafe" ] && echo 0 || echo 1)" \
  "days mode resolves ok with a commit sha" "got: '$status' '$ref'"

TEST_CURL_FAIL=1
for mode_value in "latest " "offset 1" "days 30"; do
  read -r mode value <<<"$mode_value"
  read -r status _ <<<"$(resolve_nixpkgs_pin "$mode" "$value")"
  report "$([ "$status" = "failed" ] && echo 0 || echo 1)" \
    "mode '$mode' degrades to failed with no network" "got status: $status"
done
# "specific" is the one deliberate exception — unvalidatable offline, so it
# trusts the typed value rather than blocking the install (same reasoning
# as the "trusted rather than blocked" case above, at the resolve_nixpkgs_pin
# layer this time).
read -r status ref <<<"$(resolve_nixpkgs_pin specific 99.99)"
report "$([ "$status" = "ok" ] && [ "$ref" = "nixos-99.99" ] && echo 0 || echo 1)" \
  "mode 'specific' trusts its value with no network instead" "got: '$status' '$ref'"
TEST_CURL_FAIL=""

# ── apply_nixpkgs_pin ─────────────────────────────────────────────────────
# "default" must never shell out to nix at all — overriding it here with a
# function that would fail the test if invoked proves apply_nixpkgs_pin
# really does no-op rather than relying on nix itself being harmless.
nix() { report 1 "apply_nixpkgs_pin calls nix on mode 'default'" "nix $*"; }
apply_nixpkgs_pin "/nonexistent" default ""
rc=$?
report "$([ "$rc" -eq 0 ] && echo 0 || echo 1)" \
  "apply_nixpkgs_pin no-ops on mode 'default'" "exit $rc"
unset -f nix

echo
if [ "$fails" -eq 0 ]; then
  echo "nixpkgs-pin: all tests passed"
else
  echo "nixpkgs-pin: $fails test(s) failed"
fi
exit "$fails"
