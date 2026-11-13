# shellcheck shell=bash
# scripts/installer/nixpkgs-pin.sh — resolves a nixpkgs cooldown policy
# (see wizard.sh's nixpkgs question) against GitHub's public REST API and
# bakes it into a staged flake's flake.lock. Shared by annixion-install and
# annixion-nixpkgs-cooldown.
#
# Sourced, not executed — the caller already has `set -euo pipefail`.
#
# Branch existence is checked one name at a time (GET .../branches/<name>)
# rather than paginating the repo's full branch list: nixpkgs carries
# thousands of bot-created "backport-NNNNNN-to-release-X.Y" branches, so
# scanning for the handful of "nixos-XX.YY" ones that way would be slow and
# brittle. Every function here degrades to a nonzero return on any network
# failure — never `die`s — since none of this may ever block an install.

# Prints the HTTP status for a nixpkgs branch name ("200" exists, "404"
# doesn't). Returns 1 only on a transport-level failure (no network, DNS,
# TLS, timeout) — a plain 404 is a legitimate answer, not a failure.
nixpkgs_branch_code() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    "https://api.github.com/repos/NixOS/nixpkgs/branches/$1"
}

# Finds the newest existing nixos-XX.YY release branch by probing backward
# in 6-month steps (NixOS cuts .05 and .11 branches) from a safely-future
# anchor. Prints "<year> <month>" (e.g. "26 05") on success.
_nixpkgs_latest_release_anchor() {
  local year month code candidate steps=0
  year=$(($(date -u +%Y) + 1))
  month=11
  while ((steps < 8)); do
    candidate="nixos-$(printf '%02d' $((year % 100))).$month"
    code=$(nixpkgs_branch_code "$candidate") || return 1
    [[ "$code" == "200" ]] && {
      printf '%s %s\n' "$year" "$month"
      return 0
    }
    if [[ "$month" == "11" ]]; then
      month=05
    else
      month=11
      year=$((year - 1))
    fi
    steps=$((steps + 1))
  done
  return 1
}

# Prints the branch name $1 half-year releases behind the newest one
# ($1=0 -> the newest itself). Fails if GitHub is unreachable or the
# offset reaches past nixpkgs' oldest nixos-XX.YY branch.
nixpkgs_release_branch_offset() {
  local offset="$1" year month anchor candidate code i
  anchor=$(_nixpkgs_latest_release_anchor) || return 1
  read -r year month <<<"$anchor"
  for ((i = 0; i < offset; i++)); do
    if [[ "$month" == "11" ]]; then
      month=05
    else
      month=11
      year=$((year - 1))
    fi
  done
  candidate="nixos-$(printf '%02d' $((year % 100))).$month"
  code=$(nixpkgs_branch_code "$candidate") || return 1
  [[ "$code" == "200" ]] && {
    echo "$candidate"
    return 0
  }
  return 1
}

# Normalizes a user-typed release string ("25.11" or "nixos-25.11") to the
# bare branch name. Confirms it exists when the network allows it; on a
# transport failure, trusts the value outright rather than blocking the
# install — a bogus string that slips through is caught later, loudly and
# non-destructively, by `nix flake lock` itself.
nixpkgs_normalize_release() {
  local branch="nixos-${1#nixos-}" code
  if code=$(nixpkgs_branch_code "$branch"); then
    [[ "$code" == "200" ]] && {
      echo "$branch"
      return 0
    }
    return 1
  fi
  echo "$branch"
}

# Prints the sha of the newest commit on the current latest stable branch
# that existed at or before now minus $1 days.
nixpkgs_commit_days_ago() {
  local days="$1" branch until body sha
  branch=$(nixpkgs_release_branch_offset 0) || return 1
  until=$(date -u -d "-${days} days" +%Y-%m-%dT%H:%M:%SZ)
  body=$(curl -s --max-time 10 \
    "https://api.github.com/repos/NixOS/nixpkgs/commits?sha=${branch}&until=${until}&per_page=1") || return 1
  sha=$(jq -r '.[0].sha // empty' <<<"$body")
  [[ -n "$sha" ]] || return 1
  echo "$sha"
}

# $1: mode (default|latest|specific|offset|days). $2: that mode's value
# (ignored for default/latest). Prints "<ok|failed> <ref>" on stdout, one
# line, never throws — callers branch on the "ok "/"failed" prefix.
resolve_nixpkgs_pin() {
  local mode="$1" value="$2" ref
  case "$mode" in
    default)
      printf 'ok \n'
      ;;
    latest)
      if ref=$(nixpkgs_release_branch_offset 0); then printf 'ok %s\n' "$ref"; else printf 'failed \n'; fi
      ;;
    offset)
      if ref=$(nixpkgs_release_branch_offset "$value"); then printf 'ok %s\n' "$ref"; else printf 'failed \n'; fi
      ;;
    specific)
      if ref=$(nixpkgs_normalize_release "$value"); then printf 'ok %s\n' "$ref"; else printf 'failed \n'; fi
      ;;
    days)
      if ref=$(nixpkgs_commit_days_ago "$value"); then printf 'ok %s\n' "$ref"; else printf 'failed \n'; fi
      ;;
    *)
      printf 'failed \n'
      ;;
  esac
}

# Rewrites $1/flake.lock to pin nixpkgs per the ($2 mode, $3 value) policy.
# No-ops on mode "default" — nothing to resolve, repo's own pin stands.
# Returns 1 (never dies) if resolution or the relock itself fails; callers
# must degrade to the repo's default pin, never abort on this.
apply_nixpkgs_pin() {
  local flakedir="$1" mode="$2" value="$3" pin_status ref
  [[ "$mode" == "default" ]] && return 0
  read -r pin_status ref <<<"$(resolve_nixpkgs_pin "$mode" "$value")"
  [[ "$pin_status" == "ok" ]] || return 1
  nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/${ref}" "$flakedir"
}
