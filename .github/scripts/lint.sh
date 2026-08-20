#!/usr/bin/env bash
# Runs every linter, annotates each finding, and writes a summary table.
# Errors and warnings fail the run; info-level findings are reported only.
# Set LINT_SUMMARY to a path to capture the table as markdown.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

TOOLS=(nixfmt statix deadnix shellcheck)
declare -A ERR WARN INFO
for t in "${TOOLS[@]}"; do
  ERR[$t]=0
  WARN[$t]=0
  INFO[$t]=0
done

# Actions understands error, warning and notice only; info maps to notice.
annotate() {
  local level=$1
  [ "$level" = info ] && level=notice
  printf '::%s file=%s,line=%s,col=%s,title=%s::%s\n' "$level" "$2" "$3" "$4" "$5" "$6"
}

section() {
  printf '\n\033[1m── %s ───────────────────────────\033[0m\n' "$1"
}

count() {
  local tool=$1 level=$2
  case $level in
    error) ERR[$tool]=$((ERR[$tool] + 1)) ;;
    warning) WARN[$tool]=$((WARN[$tool] + 1)) ;;
    *) INFO[$tool]=$((INFO[$tool] + 1)) ;;
  esac
}

mapfile -t nix_files < <(git ls-files '*.nix')
mapfile -t sh_files < <(git ls-files '*.sh')
# The installer carries no extension.
[ -f scripts/annixion-install ] && sh_files+=(scripts/annixion-install)

section nixfmt
if unformatted=$(nixfmt --check "${nix_files[@]}" 2>&1 >/dev/null) && [ -z "$unformatted" ]; then
  echo "formatting ok"
else
  echo "$unformatted"
  while IFS= read -r line; do
    file=${line%%:*}
    [ -f "$file" ] || continue
    count nixfmt error
    annotate error "$file" 1 1 nixfmt "Not formatted. Run 'nixfmt $file'."
  done <<<"$unformatted"
fi

section statix
statix_out=$(statix check . --format errfmt 2>/dev/null)
if [ -z "$statix_out" ]; then
  echo "no anti-patterns"
else
  echo "$statix_out"
  # ./path>line:col:severity:code:message
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file=${line%%>*}
    IFS=: read -r ln col sev code msg <<<"${line#*>}"
    [ "$sev" = E ] && level=error || level=warning
    count statix "$level"
    annotate "$level" "${file#./}" "$ln" "$col" "statix ${sev}${code}" "$msg"
  done <<<"$statix_out"
fi

section deadnix
dead_out=$(deadnix --no-lambda-pattern-names --output-format json . 2>/dev/null |
  jq -r '.file as $f | .results[] | "\($f)\t\(.line)\t\(.column)\t\(.message)"')
if [ -z "$dead_out" ]; then
  echo "no dead code"
else
  while IFS=$'\t' read -r file ln col msg; do
    [ -z "$file" ] && continue
    printf '%s:%s:%s: %s\n' "${file#./}" "$ln" "$col" "$msg"
    count deadnix warning
    annotate warning "${file#./}" "$ln" "$col" deadnix "$msg"
  done <<<"$dead_out"
fi

section shellcheck
sc_out=$(shellcheck --severity=style --format=json "${sh_files[@]}" 2>/dev/null |
  jq -r '.[] | "\(.file)\t\(.line)\t\(.column)\t\(.level)\t[SC\(.code)] \(.message)"')
if [ -z "$sc_out" ]; then
  echo "no findings"
else
  while IFS=$'\t' read -r file ln col level msg; do
    [ -z "$file" ] && continue
    printf '%s:%s:%s: %s: %s\n' "${file#./}" "$ln" "$col" "$level" "$msg"
    [ "$level" = style ] && level=info
    count shellcheck "$level"
    annotate "$level" "${file#./}" "$ln" "$col" shellcheck "$msg"
  done <<<"$sc_out"
fi

total_err=0 total_warn=0 total_info=0
for t in "${TOOLS[@]}"; do
  total_err=$((total_err + ERR[$t]))
  total_warn=$((total_warn + WARN[$t]))
  total_info=$((total_info + INFO[$t]))
done

section summary
printf '%-12s %7s %9s %6s\n' tool errors warnings info
for t in "${TOOLS[@]}"; do
  printf '%-12s %7s %9s %6s\n' "$t" "${ERR[$t]}" "${WARN[$t]}" "${INFO[$t]}"
done
printf '%-12s %7s %9s %6s\n' total "$total_err" "$total_warn" "$total_info"

if [ -n "${LINT_SUMMARY:-}" ]; then
  {
    if [ "$total_err" -eq 0 ] && [ "$total_warn" -eq 0 ]; then
      printf '**Clean** — no errors or warnings'
      [ "$total_info" -gt 0 ] && printf ', %s info-level finding(s)' "$total_info"
      printf '.\n\n'
    else
      printf '**%s error(s), %s warning(s)** across %s files.\n\n' \
        "$total_err" "$total_warn" "$((${#nix_files[@]} + ${#sh_files[@]}))"
    fi
    printf '| Tool | Errors | Warnings | Info |\n|---|--:|--:|--:|\n'
    for t in "${TOOLS[@]}"; do
      printf '| %s | %s | %s | %s |\n' "$t" "${ERR[$t]}" "${WARN[$t]}" "${INFO[$t]}"
    done
    printf '| **Total** | **%s** | **%s** | **%s** |\n' \
      "$total_err" "$total_warn" "$total_info"
  } >"$LINT_SUMMARY"
fi

[ "$total_err" -eq 0 ] && [ "$total_warn" -eq 0 ]
