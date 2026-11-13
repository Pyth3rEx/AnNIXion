#!/usr/bin/env bash
# Prebuilt Linux binaries hardcode /lib64/ld-linux-x86-64.so.2 as their
# interpreter. Without a loader there the kernel's ENOENT names the
# interpreter, but the shell reports it as if the executable were missing —
# "cannot execute: required file not found" on a file that is present and
# intact (#172). The loader and its library set are checked as built, not as
# declared: both are assembled by buildEnv, which is where a package rename
# would quietly drop one.
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

# ── The loader at the hardcoded path ───────────────────────────────────────
# stub-ld would also claim environment.ldso, and it only prints a message.
ldso=$(nix eval --raw "$CFG.environment.ldso" 2>/dev/null)
report "$(grep -q 'nix-ld' <<< "$ldso" && echo 0 || echo 1)" \
  "the ELF interpreter is nix-ld" "environment.ldso is ${ldso:-<unset>}"

# What nix-ld reads to find the real loader. Unset, it falls back to failing.
nix_ld=$(nix eval --raw "$CFG.environment.sessionVariables.NIX_LD" 2>/dev/null)
report "$([ -n "$nix_ld" ] && echo 0 || echo 1)" \
  "NIX_LD points somewhere" "NIX_LD is ${nix_ld:-<unset>}"

# ── The library set, as built ──────────────────────────────────────────────
err=$(mktemp)
drv=$(nix eval --raw "$CFG.environment.systemPackages" --apply \
  'ps: (builtins.head (builtins.filter (p: (p.name or "") == "ld-library-path") ps)).drvPath' \
  2>"$err")
out=""
[ -n "$drv" ] && out=$(nix build --no-link --print-out-paths "${drv}^*" 2>>"$err")
detail=$(tail -n 3 "$err" | tr '\n' ' ')
rm -f "$err"

if [ -z "$out" ]; then
  report 1 "the loader's library set builds" \
    "${detail:-ld-library-path did not build}"
else
  lib="$out/share/nix-ld/lib"

  report "$([ -e "$lib/ld.so" ] && echo 0 || echo 1)" \
    "the set carries a real ld.so" "no ld.so under $lib"

  # The dlopen set. These are invisible to ldd, so a GUI binary that starts
  # and then dies on a missing symbol is the failure they cause — far from
  # the loader, and easy to misread as the application's fault.
  for soname in \
    libX11.so.6 libXcursor.so.1 libXrandr.so.2 libXi.so.6 \
    libxcb.so.1 libxkbcommon.so.0 libwayland-client.so.0 \
    libGL.so.1 libdbus-1.so.3; do
    report "$([ -e "$lib/$soname" ] && echo 0 || echo 1)" \
      "$soname is discoverable" "missing from $lib"
  done
fi

echo
if [ "$fails" -gt 0 ]; then
  printf 'nix-ld: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'nix-ld: all checks passed\n'
