#!/usr/bin/env bash
# Editor settings and extensions nothing in the editor surfaces, so a profile
# rename or an upstream default flip would drop them silently. Hyper-V Enhanced
# Session reports scan codes the editor cannot trust, so dispatching on them
# turns AltGr into a bare cursor-left and AZERTY loses its third level (#163,
# microsoft/vscode#24783).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CFG='.#nixosConfigurations.AnNIXion-ci'
SYS="$CFG.config"
HM="$SYS.home-manager.users.operator"
SETTINGS="$HM.programs.vscodium.profiles.default.userSettings"
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

installed() {
  case "$exts" in
    *"\"$1\""*) report 0 "$1 is in the profile" "" ;;
    *) report 1 "$1 is in the profile" "not in the extension list" ;;
  esac
}

cd "$ROOT" || exit 1

# ── Keyboard dispatch ──────────────────────────────────────────────────────
dispatch=$(nix eval --raw "$SETTINGS.\"keyboard.dispatch\"" 2>/dev/null)
report "$([ "$dispatch" = "keyCode" ] && echo 0 || echo 1)" \
  "keybindings dispatch on the layout, not scan codes" \
  "keyboard.dispatch is ${dispatch:-<unset>}"

# ── Hidden files in the explorer ───────────────────────────────────────────
# Unsetting this is not the same as emptying it: with no value the editor
# falls back to a default list that hides .git, which is what #162 reported.
excluded=$(nix eval --json "$SETTINGS.\"files.exclude\"" 2>/dev/null)
report "$([ "$excluded" = "{}" ] && echo 0 || echo 1)" \
  "the explorer hides nothing" \
  "files.exclude is ${excluded:-<unset>}"

# ── Shell language support ─────────────────────────────────────────────────
exts=$(nix eval --json "$HM.programs.vscodium.profiles.default.extensions" \
  --apply 'map (e: e.vscodeExtUniqueId or e.pname)' 2>/dev/null)
installed mads-hartmann.bash-ide-vscode
installed timonwong.shellcheck

formatter=$(nix eval --raw "$SETTINGS.\"[shellscript]\".\"editor.defaultFormatter\"" 2>/dev/null)
report "$([ "$formatter" = "mads-hartmann.bash-ide-vscode" ] && echo 0 || echo 1)" \
  "shell scripts format with the bash server" \
  "formatter is ${formatter:-<unset>}"

# shfmt reads its indent off the editor, so these are the -i 2 -ci every script
# in the repo is written to; losing them reformats all of them on first save.
indent=$(nix eval --json "$SETTINGS.\"[shellscript]\".\"editor.tabSize\"" 2>/dev/null)
spaces=$(nix eval --json "$SETTINGS.\"[shellscript]\".\"editor.insertSpaces\"" 2>/dev/null)
case_indent=$(nix eval --json "$SETTINGS.\"bashIde.shfmt.caseIndent\"" 2>/dev/null)
report "$([ "$indent" = 2 ] && [ "$spaces" = true ] && [ "$case_indent" = true ] && echo 0 || echo 1)" \
  "shfmt formats to the style the scripts are written in" \
  "tabSize=${indent:-<unset>} insertSpaces=${spaces:-<unset>} caseIndent=${case_indent:-<unset>}"

# Empty, not absent: nixpkgs patches the path to the store shellcheck, and the
# server would then report every finding timonwong.shellcheck already reports.
sc_path=$(nix eval --json "$SETTINGS.\"bashIde.shellcheckPath\"" 2>/dev/null)
report "$([ "$sc_path" = '""' ] && echo 0 || echo 1)" \
  "shellcheck is reported once, not twice" \
  "bashIde.shellcheckPath is ${sc_path:-<unset>}"

# ── PowerShell ─────────────────────────────────────────────────────────────
# nixpkgs names it ms-vscode.PowerShell; the extension's own manifest spells
# the same id ms-vscode.powershell, which is what a setting has to say.
installed ms-vscode.PowerShell

# Unpatched by nixpkgs: an exe path that is not a real store pwsh means the
# language server never starts, and nothing in the editor says why.
pwsh=$(nix eval --raw "$SETTINGS.\"powershell.powerShellAdditionalExePaths\".\"PowerShell 7\"" 2>/dev/null)
installed_pwsh=$(nix eval --raw "$CFG.pkgs.powershell.outPath" 2>/dev/null)
report "$([ -n "$installed_pwsh" ] && [ "$pwsh" = "$installed_pwsh/bin/pwsh" ] && echo 0 || echo 1)" \
  "the PowerShell extension is pointed at the pwsh the system installs" \
  "powerShellAdditionalExePaths is ${pwsh:-<unset>}"

# The name on the path above, or the extension ignores it and falls back to
# whatever pwsh PATH turns up.
default=$(nix eval --raw "$SETTINGS.\"powershell.powerShellDefaultVersion\"" 2>/dev/null)
report "$([ "$default" = "PowerShell 7" ] && echo 0 || echo 1)" \
  "that pwsh is the one it starts" \
  "powerShellDefaultVersion is ${default:-<unset>}"

prompt=$(nix eval --json "$SETTINGS.\"powershell.promptToUpdatePowerShell\"" 2>/dev/null)
report "$([ "$prompt" = false ] && echo 0 || echo 1)" \
  "the editor does not check for PowerShell releases" \
  "promptToUpdatePowerShell is ${prompt:-<unset>}"

ps_formatter=$(nix eval --raw "$SETTINGS.\"[powershell]\".\"editor.defaultFormatter\"" 2>/dev/null)
report "$([ "$ps_formatter" = "ms-vscode.powershell" ] && echo 0 || echo 1)" \
  "PowerShell scripts format with the extension" \
  "formatter is ${ps_formatter:-<unset>}"

echo
if [ "$fails" -gt 0 ]; then
  printf 'vscodium-settings: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'vscodium-settings: all checks passed\n'
