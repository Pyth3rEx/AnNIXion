#!/usr/bin/env bash
# /etc/hosts is deliberately a real file rather than the store symlink, so root
# can edit it. The mode it lands on has a floor: every non-root name lookup
# reads it, and rootlesskit copies it into the container namespace on its way
# up. At 0700 the rootless daemon dies on "open /etc/hosts: permission denied",
# and because its unit carries TimeoutStartUSec=infinity it hangs in
# `activating` rather than failing — which parks the user's default.target, and
# with it any nixos-rebuild switch that waits on the user bus. Nothing errors.
# The rebuild simply never returns.
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

mode=$(nix eval --raw "$CFG.environment.etc.hosts.mode" 2>/dev/null)
if [ -z "$mode" ]; then
  echo "etc-hosts: could not evaluate environment.etc.hosts.mode"
  exit 1
fi

# The default is the string "symlink" — a read-only link into the store, which
# root cannot edit. Setting any octal mode is what makes it a real file.
report "$([ "$mode" != "symlink" ] && echo 0 || echo 1)" \
  "/etc/hosts is a real file, not the store symlink" \
  "mode is \"symlink\", so root cannot edit it"

if [ "$mode" != "symlink" ]; then
  report "$([[ "$mode" =~ ^0?[0-7]{3}$ ]] && echo 0 || echo 1)" \
    "/etc/hosts mode is octal" "mode is \"$mode\""

  if [[ "$mode" =~ ^0?[0-7]{3}$ ]]; then
    octal=${mode#0}
    other=$((${octal:2:1}))
    group=$((${octal:1:1}))
    owner=$((${octal:0:1}))

    report "$(((other & 4) != 0 ? 0 : 1))" \
      "/etc/hosts is world-readable" \
      "mode $mode denies other read — non-root name lookups and rootless Docker both break"

    report "$(((group & 4) != 0 ? 0 : 1))" \
      "/etc/hosts is group-readable" "mode $mode denies group read"

    report "$(((owner & 2) != 0 ? 0 : 1))" \
      "root can still write /etc/hosts" \
      "mode $mode denies owner write, which is the reason the file is mutable at all"
  fi
fi

# The dependency the mode floor exists for. If the runtime ever stops being
# rootless this test still holds, but the reasoning above changes.
rootless=$(nix eval "$CFG.annixion.docker.rootless" 2>/dev/null)
report "$([ "$rootless" = "true" ] || [ "$rootless" = "false" ] && echo 0 || echo 1)" \
  "the container runtime declares a rootless setting" \
  "annixion.docker.rootless did not evaluate"

echo
if [ "$fails" -gt 0 ]; then
  printf 'etc-hosts: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'etc-hosts: all checks passed (mode %s, rootless=%s)\n' "$mode" "$rootless"
