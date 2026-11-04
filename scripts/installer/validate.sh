# shellcheck shell=bash
# scripts/installer/validate.sh — version and eval checks for a user/
# config, shared by annixion-install (before any disk is touched) and
# annixion-config-doctor (on an already-installed system).
#
# Sourced, not executed — the caller already has `set -euo pipefail`.

# Bumped only alongside a breaking annixion.* rename that system/compat.nix
# cannot shim mechanically. A plain rename belongs in compat.nix instead and
# needs no bump: an older, still-shimmable config keeps evaluating.
# shellcheck disable=SC2034 # read by annixion-install and annixion-config-doctor
MIN_CONFIG_VERSION="0.5.0"

# Prints the version a user/ folder was stamped with, and whether it asked
# to skip the wizard next time, as "<version> <skip|noskip>". Empty version
# means no stamp at all — hand-written, or from before this existed.
read_config_stamp() {
  local dir="$1"
  if [[ -f "$dir/user/.annixion-version" ]]; then
    local version skip
    version=$(sed -n '1p' "$dir/user/.annixion-version" | tr -d '[:space:]')
    skip=$(sed -n '2p' "$dir/user/.annixion-version" | tr -d '[:space:]')
    printf '%s %s\n' "$version" "${skip:-noskip}"
  else
    printf ' noskip\n'
  fi
}

# 0 (true) if $1 >= $2, as dotted version numbers.
version_ge() {
  local a="$1" b="$2"
  [[ "$a" == "$b" ]] && return 0
  [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" == "$a" ]]
}

# Evaluates a flake checkout ($1) the same way nixosConfigurations.AnNIXion-ci
# does — system/hardware-stub.nix stands in for a real machine, so this costs
# seconds rather than a formatted disk. Prints "ok" or "broken: <nix's own
# error>" on stdout; never throws.
eval_flake() {
  local flake="$1"
  local out
  if out=$(nix eval --raw "$flake#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel.drvPath" 2>&1); then
    echo "ok"
  else
    echo "broken: $(tail -1 <<<"$out")"
  fi
}

# Stages a candidate user/ folder ($1) into an already-cloned flake checkout
# ($2) — a different directory, never the same one a user is editing live —
# and evaluates it with eval_flake.
validate_config() {
  local candidate="$1" flake="$2"

  if [[ -f "$candidate/user/configuration.nix" ]]; then
    # system.stateVersion is machine state, not a preference: inheriting an
    # old one would silently change stateful defaults with no error.
    sed '/system\.stateVersion/d' "$candidate/user/configuration.nix" \
      >"$flake/user/configuration.nix"
  fi
  if [[ -f "$candidate/user/home.nix" ]]; then
    cp "$candidate/user/home.nix" "$flake/user/home.nix"
  fi

  eval_flake "$flake"
}

# Reads back the handful of options the wizard pre-fills from, out of a
# flake checkout validate_config has already staged a candidate into.
# Prints one JSON object on stdout; wizard.sh picks it apart with jq.
extract_defaults() {
  local flake="$1"
  nix eval --json "$flake#nixosConfigurations.AnNIXion-ci.config" --apply '
    c: {
      hostname = c.networking.hostName;
      timezone = c.time.timeZone;
      keymap = c.console.keyMap;
      compositing = c.annixion.desktop.compositing;
      profiles = {
        redteam = c.annixion.firefox.profiles.redteam.enable;
        osint = c.annixion.firefox.profiles.osint.enable;
        puppet = c.annixion.firefox.profiles.puppet.enable;
        untrusted = c.annixion.firefox.profiles.untrusted.enable;
      };
    }
  '
}
