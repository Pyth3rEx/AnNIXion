# shellcheck shell=bash
# scripts/installer/wizard.sh — the TUI wizard: collects installer answers
# with gum and renders them into a user/ folder.
#
# Sourced, not executed — the caller already has `set -euo pipefail`.

# AnNIXion red — gum's own palette knobs, read as env vars.
export GUM_INPUT_CURSOR_FOREGROUND="196"
export GUM_INPUT_PROMPT_FOREGROUND="196"
export GUM_CONFIRM_SELECTED_FOREGROUND="196"
export GUM_CHOOSE_CURSOR_FOREGROUND="196"
export GUM_CHOOSE_SELECTED_FOREGROUND="196"
export GUM_FILTER_INDICATOR_FOREGROUND="196"
export GUM_FILTER_MATCH_FOREGROUND="196"
export GUM_SPIN_SPINNER_FOREGROUND="196"

# Answers land in these globals — simpler than threading a struct through
# bash, and run_wizard and write_user_folder are always called back to back.
WIZ_HOSTNAME=""
WIZ_TIMEZONE=""
WIZ_KEYMAP=""
WIZ_OS_HASH=""
WIZ_SYSREPTOR_HASH=""
WIZ_COMPOSITING="false"
WIZ_PROFILE_REDTEAM="true"
WIZ_PROFILE_OSINT="true"
WIZ_PROFILE_PUPPET="true"
WIZ_PROFILE_UNTRUSTED="true"
WIZ_SKIP_NEXT_TIME="false"

# $1: JSON from installer/validate.sh's extract_defaults, to pre-fill every
# prompt from a found-but-not-skippable config. Empty runs with the
# hard-coded defaults documented in user/README.md.
run_wizard() {
  local defaults="${1:-}"
  local def_hostname def_timezone def_keymap def_compositing
  local def_redteam def_osint def_puppet def_untrusted

  if [[ -n "$defaults" ]]; then
    def_hostname=$(jq -r '.hostname' <<<"$defaults")
    def_timezone=$(jq -r '.timezone' <<<"$defaults")
    def_keymap=$(jq -r '.keymap' <<<"$defaults")
    def_compositing=$(jq -r '.compositing' <<<"$defaults")
    def_redteam=$(jq -r '.profiles.redteam' <<<"$defaults")
    def_osint=$(jq -r '.profiles.osint' <<<"$defaults")
    def_puppet=$(jq -r '.profiles.puppet' <<<"$defaults")
    def_untrusted=$(jq -r '.profiles.untrusted' <<<"$defaults")
  else
    # || true: head closing early once it has its 7 bytes SIGPIPEs tr, and
    # that is a real failure under this script's inherited `set -o pipefail`.
    def_hostname="DESKTOP-$(tr -dc 'A-Z0-9' </dev/urandom | head -c 7 || true)"
    def_timezone="UTC"
    def_keymap="us"
    def_compositing="false"
    def_redteam="true"
    def_osint="true"
    def_puppet="true"
    def_untrusted="true"
  fi

  gum style --foreground 196 --bold --border double --padding "1 2" "AnNIXion installer"

  WIZ_HOSTNAME=$(gum input --header "Hostname" --value "$def_hostname")

  local pw1 pw2
  while true; do
    pw1=$(gum input --password --header "Account password (operator)")
    pw2=$(gum input --password --header "Again, to confirm")
    if [[ -z "$pw1" ]]; then
      gum style --foreground 196 "An empty password is not one."
      continue
    fi
    [[ "$pw1" == "$pw2" ]] && break
    gum style --foreground 196 "Those did not match — try again."
  done
  WIZ_OS_HASH=$(mkpasswd -m sha-512 --stdin <<<"$pw1")
  # Django's own format, matching catalog/tools/productivity/sysreptor.nix's
  # mint_hash — the plaintext never otherwise reaches the config.
  WIZ_SYSREPTOR_HASH=$(
    SYSREPTOR_NEW_PW="$pw1" python3 -c '
import base64, hashlib, os, secrets, string

alphabet = string.ascii_letters + string.digits
salt = "".join(secrets.choice(alphabet) for _ in range(22))
iterations = 600000
dk = hashlib.pbkdf2_hmac("sha256", os.environ["SYSREPTOR_NEW_PW"].encode(), salt.encode(), iterations)
print("pbkdf2_sha256$%d$%s$%s" % (iterations, salt, base64.b64encode(dk).decode()))
'
  )
  pw1=""
  pw2=""

  WIZ_TIMEZONE=$(timedatectl list-timezones | gum filter --header "Timezone" --value "$def_timezone")
  WIZ_KEYMAP=$(localectl list-keymaps | gum filter --header "Keyboard layout" --value "$def_keymap")

  local preselect=()
  [[ "$def_redteam" == "true" ]] && preselect+=("Red Team")
  [[ "$def_osint" == "true" ]] && preselect+=("OSINT")
  [[ "$def_puppet" == "true" ]] && preselect+=("Puppet Master")
  [[ "$def_untrusted" == "true" ]] && preselect+=("Unsafe Browser")

  local chosen=()
  while [[ ${#chosen[@]} -eq 0 ]]; do
    mapfile -t chosen < <(
      gum choose --no-limit --header "Firefox profiles to build (at least one)" \
        --selected "$(
          IFS=,
          echo "${preselect[*]}"
        )" \
        "Red Team" "OSINT" "Puppet Master" "Unsafe Browser"
    )
    [[ ${#chosen[@]} -eq 0 ]] && gum style --foreground 196 "Pick at least one."
  done
  WIZ_PROFILE_REDTEAM="false"
  WIZ_PROFILE_OSINT="false"
  WIZ_PROFILE_PUPPET="false"
  WIZ_PROFILE_UNTRUSTED="false"
  for c in "${chosen[@]}"; do
    case "$c" in
      "Red Team") WIZ_PROFILE_REDTEAM="true" ;;
      "OSINT") WIZ_PROFILE_OSINT="true" ;;
      "Puppet Master") WIZ_PROFILE_PUPPET="true" ;;
      "Unsafe Browser") WIZ_PROFILE_UNTRUSTED="true" ;;
    esac
  done

  local comp_default="$def_compositing"
  local comp_has_render_node="false"
  if compgen -G "/dev/dri/renderD*" >/dev/null 2>&1; then
    comp_default="true"
    comp_has_render_node="true"
  fi
  if gum confirm --default="$comp_default" \
    "Turn on desktop compositing — blur, animations, tear-free output. Costs about three quarters of a core continuously on a guest with no render node, and this machine $(
      [[ "$comp_has_render_node" == true ]] && echo "has one" || echo "does not"
    )."; then
    WIZ_COMPOSITING="true"
  else
    WIZ_COMPOSITING="false"
  fi

  if gum confirm "Reuse these answers next time without asking?"; then
    WIZ_SKIP_NEXT_TIME="true"
  else
    WIZ_SKIP_NEXT_TIME="false"
  fi
}

# Renders the answers run_wizard collected into $1/user/configuration.nix and
# $1/user/.annixion-version, stamped with version $2. Does not touch
# user/home.nix — nothing collected here belongs there (see user/README.md).
write_user_folder() {
  local dest="$1" version="$2"
  mkdir -p "$dest/user"

  cat >"$dest/user/configuration.nix" <<EOF
# Generated by annixion-install's wizard — see user/README.md to hand-edit.
{ lib, ... }:
{
  networking.hostName = "$WIZ_HOSTNAME";
  time.timeZone = "$WIZ_TIMEZONE";
  console.keyMap = "$WIZ_KEYMAP";

  users.users.operator.hashedPassword = "$WIZ_OS_HASH";
  annixion.sysreptor.hashedPassword = "$WIZ_SYSREPTOR_HASH";

  annixion.desktop.compositing = $WIZ_COMPOSITING;

  annixion.firefox.profiles = {
    redteam.enable = $WIZ_PROFILE_REDTEAM;
    osint.enable = $WIZ_PROFILE_OSINT;
    puppet.enable = $WIZ_PROFILE_PUPPET;
    untrusted.enable = $WIZ_PROFILE_UNTRUSTED;
  };
}
EOF

  local skip="noskip"
  [[ "$WIZ_SKIP_NEXT_TIME" == "true" ]] && skip="skip"
  printf '%s\n%s\n' "$version" "$skip" >"$dest/user/.annixion-version"
}
