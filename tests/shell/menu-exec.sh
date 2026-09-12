#!/usr/bin/env bash
# A catalog tool's Exec= line never runs inside an interactive shell: a "gui"
# launch is execvp'd straight off the .desktop file, and "term"/"hold"/"named"
# wrap it in `konsole -e` or `zsh -c "...; exec zsh"`, both non-interactive —
# neither sources ~/.zshrc. A command that only exists as a
# programs.zsh.shellAliases entry is invisible in both cases: it runs fine
# from a prompt already inside an interactive shell and fails everywhere else
# with "command not found". That is exactly how the "SecList" menu entry broke
# in #126 — `seclists` was a shellAlias, not a real binary on PATH.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HM='.#nixosConfigurations.AnNIXion-ci.config.home-manager.users.operator'
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

err=$(mktemp)
trap 'rm -f "$err"' EXIT
if ! dump=$(nix build --no-link --print-out-paths .#catalog-json 2>"$err"); then
  printf 'menu-exec: could not build .#catalog-json\n%s\n' "$(cat "$err")"
  exit 1
fi
catalog=$(cat "$dump")

aliases=$(nix eval --json "$HM.programs.zsh.shellAliases" --apply 'builtins.attrNames' 2>"$err")
if [ -z "$aliases" ]; then
  printf 'menu-exec: could not evaluate shell aliases\n%s\n' "$(cat "$err")"
  exit 1
fi

bad=""
while read -r tool first; do
  [ -z "$tool" ] && continue
  if jq -e --arg a "$first" 'index($a) != null' <<<"$aliases" >/dev/null; then
    bad="$bad $tool(exec=$first)"
  fi
done < <(jq -r '.tools | to_entries[] | "\(.key) \(.value.exec | split(" ")[0])"' <<<"$catalog")

report "$([ -z "$bad" ] && echo 0 || echo 1)" \
  "no menu entry execs a shell-alias-only command" \
  "these only exist inside an interactive zsh, so a menu launch (non-interactive) can't find them:$bad"

echo
if [ "$fails" -gt 0 ]; then
  printf 'menu-exec: %d check(s) failed\n' "$fails"
  exit 1
fi
echo "menu-exec: all checks passed"
