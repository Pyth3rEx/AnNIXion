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
# gum's default spinner is Braille glyphs, absent from the plain console
# font the live ISO boots with — every frame renders as nothing, so a
# genuinely running spinner looks frozen. line's |/-\ frames are plain
# ASCII, guaranteed to exist in any console font.
export GUM_SPIN_SPINNER="line"

# Answers land in these globals — simpler than threading a struct through
# bash, and run_wizard and write_user_folder are always called back to back.
WIZ_HOSTNAME=""
# "operator" is always the Nix attribute key (users.users.operator) — this
# only ever becomes users.users.operator.name, the account's real login
# name. Everything else in the repo that needs it (home-manager, sysreptor,
# docker, the VPN module) already reads that option dynamically rather than
# hardcoding "operator", so this is the one place that needs to ask.
WIZ_USERNAME=""
WIZ_TIMEZONE=""
WIZ_KEYMAP=""
WIZ_OS_HASH=""
WIZ_SYSREPTOR_HASH=""
# Empty means "share the OS account's" — annixion.sysreptor.user's own Nix
# default already resolves to that, so the generated config just omits the
# line rather than spelling out "operator" a second, redundant way.
WIZ_SYSREPTOR_USER=""
WIZ_COMPOSITING="false"
WIZ_PROFILE_REDTEAM="true"
WIZ_PROFILE_OSINT="true"
WIZ_PROFILE_PUPPET="true"
WIZ_PROFILE_UNTRUSTED="true"
WIZ_EXAMPLE_HTB="false"
WIZ_EXAMPLE_GIT="false"
WIZ_EXAMPLE_ZSH="false"
WIZ_GIT_NAME=""
WIZ_GIT_EMAIL=""
WIZ_SKIP_NEXT_TIME="false"

# Clears and redraws the "AnNIXion installer" banner — the caller's own
# clear would otherwise wipe it along with everything else, so it only
# ever showed up on the very first question instead of every one of them.
wizard_screen() {
  clear 2>/dev/null || true
  gum style --foreground 196 --bold --border double --padding "1 2" "AnNIXion installer"
  echo
}

# $1: JSON from installer/validate.sh's extract_defaults, to pre-fill every
# prompt from a found-but-not-skippable config. Empty runs with the
# hard-coded defaults documented in user/README.md.
run_wizard() {
  local defaults="${1:-}"
  local def_hostname def_username def_timezone def_keymap def_compositing
  local def_redteam def_osint def_puppet def_untrusted
  local def_sysreptor_user def_sysreptor_shared

  if [[ -n "$defaults" ]]; then
    def_hostname=$(jq -r '.hostname' <<<"$defaults")
    def_username=$(jq -r '.username' <<<"$defaults")
    def_timezone=$(jq -r '.timezone' <<<"$defaults")
    def_keymap=$(jq -r '.keymap' <<<"$defaults")
    def_compositing=$(jq -r '.compositing' <<<"$defaults")
    def_redteam=$(jq -r '.profiles.redteam' <<<"$defaults")
    def_osint=$(jq -r '.profiles.osint' <<<"$defaults")
    def_puppet=$(jq -r '.profiles.puppet' <<<"$defaults")
    def_untrusted=$(jq -r '.profiles.untrusted' <<<"$defaults")
    def_sysreptor_user=$(jq -r '.sysreptorUser' <<<"$defaults")
  else
    # || true: head closing early once it has its 7 bytes SIGPIPEs tr, and
    # that is a real failure under this script's inherited `set -o pipefail`.
    def_hostname="DESKTOP-$(tr -dc 'A-Z0-9' </dev/urandom | head -c 7 || true)"
    def_username="operator"
    def_timezone="UTC"
    def_keymap="us"
    def_compositing="false"
    def_redteam="true"
    def_osint="true"
    def_puppet="true"
    def_untrusted="true"
    def_sysreptor_user="operator"
  fi
  # annixion.sysreptor.user's own default already resolves to whatever the
  # OS account's name is when nothing set it explicitly, so this can't tell
  # "shared" apart from "explicitly set to the same name" — close enough:
  # either way "shared" is the right starting answer to pre-select.
  if [[ "$def_sysreptor_user" == "$def_username" ]]; then
    def_sysreptor_shared="true"
  else
    def_sysreptor_shared="false"
  fi

  wizard_screen

  WIZ_HOSTNAME=$(gum input --header "Hostname" --value "$def_hostname")

  wizard_screen
  while true; do
    WIZ_USERNAME=$(gum input --header "Account username" --value "$def_username")
    [[ "$WIZ_USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
    gum style --foreground 196 "Lowercase letters, digits, _ and -, starting with a letter or _."
  done

  # gum has no notion of one prompt replacing the last — each one just
  # renders and leaves its answer printed where it was, so back-to-back
  # prompts (the two passwords below, then later the two yes/no questions)
  # pile up underneath each other instead of each getting its own screen.
  # wizard_screen clears and redraws the banner, rather than a bare clear,
  # so it's still there for every question, not just the first.
  wizard_screen
  local pw1 pw2
  while true; do
    pw1=$(gum input --password --header "Account password ($WIZ_USERNAME)")
    pw2=$(gum input --password --header "Again, to confirm")
    if [[ -z "$pw1" ]]; then
      gum style --foreground 196 "An empty password is not one."
      continue
    fi
    [[ "$pw1" == "$pw2" ]] && break
    gum style --foreground 196 "Those did not match — try again."
  done
  WIZ_OS_HASH=$(mkpasswd -m sha-512 --stdin <<<"$pw1")
  pw2=""

  wizard_screen
  local sysreptor_pw="$pw1"
  if gum confirm --default="$def_sysreptor_shared" "Use the OS account's username and password for SysReptor too?"; then
    WIZ_SYSREPTOR_USER=""
  else
    WIZ_SYSREPTOR_USER=$(gum input --header "SysReptor username" --value "$def_sysreptor_user")
    local sr_pw1 sr_pw2
    while true; do
      sr_pw1=$(gum input --password --header "SysReptor password")
      sr_pw2=$(gum input --password --header "Again, to confirm")
      if [[ -z "$sr_pw1" ]]; then
        gum style --foreground 196 "An empty password is not one."
        continue
      fi
      [[ "$sr_pw1" == "$sr_pw2" ]] && break
      gum style --foreground 196 "Those did not match — try again."
    done
    sysreptor_pw="$sr_pw1"
    sr_pw1=""
    sr_pw2=""
  fi
  pw1=""
  # Django's own format, matching catalog/tools/productivity/sysreptor.nix's
  # mint_hash — the plaintext never otherwise reaches the config.
  WIZ_SYSREPTOR_HASH=$(
    SYSREPTOR_NEW_PW="$sysreptor_pw" python3 -c '
import base64, hashlib, os, secrets, string

alphabet = string.ascii_letters + string.digits
salt = "".join(secrets.choice(alphabet) for _ in range(22))
iterations = 600000
dk = hashlib.pbkdf2_hmac("sha256", os.environ["SYSREPTOR_NEW_PW"].encode(), salt.encode(), iterations)
print("pbkdf2_sha256$%d$%s$%s" % (iterations, salt, base64.b64encode(dk).decode()))
'
  )
  sysreptor_pw=""

  wizard_screen
  WIZ_TIMEZONE=$(timedatectl list-timezones | gum filter --header "Timezone" --value "$def_timezone")
  WIZ_KEYMAP=$(localectl list-keymaps | gum filter --header "Keyboard layout" --value "$def_keymap")

  wizard_screen
  local preselect=()
  [[ "$def_redteam" == "true" ]] && preselect+=("Red Team")
  [[ "$def_osint" == "true" ]] && preselect+=("OSINT")
  [[ "$def_puppet" == "true" ]] && preselect+=("Puppet Master")
  [[ "$def_untrusted" == "true" ]] && preselect+=("Unsafe Browser")

  local chosen=()
  while [[ ${#chosen[@]} -eq 0 ]]; do
    mapfile -t chosen < <(
      # gum's defaults (✓ vs a plain • for both the unselected AND the
      # cursor row, told apart only by colour) are exactly what made this
      # unreadable. [x]/[ ] can't be confused for one another or for the
      # separate "> " cursor marker gum already draws in front of a row.
      gum choose --no-limit --header "Firefox profiles to build (at least one)" \
        --selected-prefix "[x] " --unselected-prefix "[ ] " --cursor-prefix "[ ] " \
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

  wizard_screen
  # Optional, unlike the Firefox profiles above — none picked is a valid
  # answer, so no "pick at least one" loop here.
  local chosen_examples=()
  mapfile -t chosen_examples < <(
    gum choose --no-limit --header "Example configs to enable (edit the values afterward — see user/README.md)" \
      --selected-prefix "[x] " --unselected-prefix "[ ] " --cursor-prefix "[ ] " \
      "HTB networking helper (DNS, VPN hosts)" \
      "Git identity override" \
      "Zsh banner + recon aliases"
  )
  WIZ_EXAMPLE_HTB="false"
  WIZ_EXAMPLE_GIT="false"
  WIZ_EXAMPLE_ZSH="false"
  for c in "${chosen_examples[@]}"; do
    case "$c" in
      "HTB networking helper"*) WIZ_EXAMPLE_HTB="true" ;;
      "Git identity override") WIZ_EXAMPLE_GIT="true" ;;
      "Zsh banner + recon aliases") WIZ_EXAMPLE_ZSH="true" ;;
    esac
  done

  if [[ "$WIZ_EXAMPLE_GIT" == "true" ]]; then
    wizard_screen
    # Excluding " \ | & rather than escaping them through to the sed
    # replacement write_user_folder uses on git.nix (itself embedded in a
    # Nix string) — simpler and more robust than two layers of escaping
    # for characters a real name or email essentially never needs anyway.
    while true; do
      WIZ_GIT_NAME=$(gum input --header "Git user.name")
      if [[ -z "$WIZ_GIT_NAME" ]]; then
        gum style --foreground 196 "A name is not optional for git commits."
      elif [[ "$WIZ_GIT_NAME" == *[\"\\\|\&]* ]]; then
        gum style --foreground 196 'Avoid " \ | & here — edit user/examples/git.nix by hand for anything fancier.'
      else
        break
      fi
    done
    while true; do
      WIZ_GIT_EMAIL=$(gum input --header "Git user.email")
      if [[ -z "$WIZ_GIT_EMAIL" ]]; then
        gum style --foreground 196 "An email is not optional for git commits."
      elif [[ "$WIZ_GIT_EMAIL" == *[\"\\\|\&]* ]]; then
        gum style --foreground 196 'Avoid " \ | & here — edit user/examples/git.nix by hand for anything fancier.'
      else
        break
      fi
    done
  fi

  wizard_screen
  local comp_default="$def_compositing"
  local comp_has_render_node="false"
  if compgen -G "/dev/dri/renderD*" >/dev/null 2>&1; then
    comp_default="true"
    comp_has_render_node="true"
  fi
  # gum confirm has no --width of its own, so a long prompt wraps however
  # the terminal reports its size — unreliable on a raw console. gum style
  # does take --width, so the explanation goes there and confirm only ever
  # has to lay out a short question and two buttons.
  gum style --width 70 "Enhanced graphics (desktop compositing) — blur, animations, tear-free output. Costs about three quarters of a core continuously on a guest with no render node, and this machine $(
    [[ "$comp_has_render_node" == true ]] && echo "has one" || echo "does not"
  )."
  if gum confirm --default="$comp_default" "Turn it on?"; then
    WIZ_COMPOSITING="true"
  else
    WIZ_COMPOSITING="false"
  fi

  wizard_screen
  if gum confirm "Reuse these answers next time without asking?"; then
    WIZ_SKIP_NEXT_TIME="true"
  else
    WIZ_SKIP_NEXT_TIME="false"
  fi
}

# Renders the answers run_wizard collected into $1/user/configuration.nix
# and $1/user/.annixion-version, stamped with version $2. Also touches
# $1/user/home.nix — just to uncomment the git/zsh example imports already
# sitting there commented out, if chosen; nothing else collected here
# belongs there (see user/README.md).
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
$([[ "$WIZ_USERNAME" != "operator" ]] && echo "  users.users.operator.name = \"$WIZ_USERNAME\";")
  annixion.sysreptor.hashedPassword = "$WIZ_SYSREPTOR_HASH";
$([[ -n "$WIZ_SYSREPTOR_USER" ]] && echo "  annixion.sysreptor.user = \"$WIZ_SYSREPTOR_USER\";")

  annixion.desktop.compositing = $WIZ_COMPOSITING;

  annixion.firefox.profiles = {
    redteam.enable = $WIZ_PROFILE_REDTEAM;
    osint.enable = $WIZ_PROFILE_OSINT;
    puppet.enable = $WIZ_PROFILE_PUPPET;
    untrusted.enable = $WIZ_PROFILE_UNTRUSTED;
  };

  imports = [
$([[ "$WIZ_EXAMPLE_HTB" == "true" ]] && echo "    ./examples/hackthebox.nix")
  ];
}
EOF

  # git.nix and zsh.nix are home-manager-level (user/home.nix), not
  # system-level like hackthebox.nix above — uncommented in place rather
  # than regenerated, since home.nix isn't otherwise this function's to
  # overwrite.
  if [[ -f "$dest/user/home.nix" ]]; then
    [[ "$WIZ_EXAMPLE_GIT" == "true" ]] && sed -i 's|# \./examples/git\.nix|./examples/git.nix|' "$dest/user/home.nix"
    [[ "$WIZ_EXAMPLE_ZSH" == "true" ]] && sed -i 's|# \./examples/zsh\.nix|./examples/zsh.nix|' "$dest/user/home.nix"
  fi

  # git.nix ships with placeholder userName/userEmail — fill in the real
  # ones collected above rather than leaving "Your Name" imported as-is.
  # sed, not a Nix-level override in home.nix: git.nix sets these as plain
  # values, not lib.mkDefault, so a second definition anywhere else would
  # just be a conflicting-definition eval error. Safe to interpolate
  # directly — run_wizard already rejected " \ | & in both values, which
  # is everything that could break either the sed replacement or the Nix
  # string it's going into.
  if [[ "$WIZ_EXAMPLE_GIT" == "true" && -f "$dest/user/examples/git.nix" ]]; then
    sed -i \
      -e "s|userName = \"Your Name\";|userName = \"$WIZ_GIT_NAME\";|" \
      -e "s|userEmail = \"you@example.com\";|userEmail = \"$WIZ_GIT_EMAIL\";|" \
      "$dest/user/examples/git.nix"
  fi

  local skip="noskip"
  [[ "$WIZ_SKIP_NEXT_TIME" == "true" ]] && skip="skip"
  printf '%s\n%s\n' "$version" "$skip" >"$dest/user/.annixion-version"
}
