#!/usr/bin/env bash
# Runs every linter, annotates each finding, and writes a summary table.
# Errors and warnings fail the run; info-level findings are reported only.
# A tool that cannot run counts as an error — silence must not read as clean.
# Set LINT_SUMMARY to a path to capture the table as markdown, LINT_COUNTS to
# record the tallies, and LINT_BASELINE to a counts file from another revision
# to show how this one moves each number.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

TOOLS=(nixfmt statix deadnix shellcheck nix-eval)
declare -A ERR WARN INFO
for t in "${TOOLS[@]}"; do
  ERR[$t]=0
  WARN[$t]=0
  INFO[$t]=0
done

ERRLOG=$(mktemp)
trap 'rm -f "$ERRLOG"' EXIT

declare -A BASE
if [ -n "${LINT_BASELINE:-}" ] && [ -f "${LINT_BASELINE}" ]; then
  while read -r tool e w i; do
    [ -n "$tool" ] || continue
    BASE[$tool.error]=$e
    BASE[$tool.warning]=$w
    BASE[$tool.info]=$i
  done <"$LINT_BASELINE"
fi

# "2 (+1)" when the count moved against the baseline, plain "2" otherwise.
delta() {
  local key=$1 cur=$2 base d
  base=${BASE[$key]:-}
  if [ -z "$base" ]; then
    printf '%s' "$cur"
    return
  fi
  d=$((cur - base))
  if [ "$d" -gt 0 ]; then
    printf '%s (+%s)' "$cur" "$d"
  elif [ "$d" -lt 0 ]; then
    printf '%s (%s)' "$cur" "$d"
  else
    printf '%s' "$cur"
  fi
}

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

broke() {
  printf '%s could not run (exit %s):\n' "$1" "$2"
  sed 's/^/  /' "$ERRLOG"
  count "$1" error
  printf '::error title=%s::%s could not run, so its result is not trustworthy\n' "$1" "$1"
}

mapfile -t nix_files < <(git ls-files '*.nix')
mapfile -t sh_files < <(git ls-files '*.sh')
# The installer carries no extension.
[ -f scripts/annixion-install ] && sh_files+=(scripts/annixion-install)

section nixfmt
# nixfmt reports unformatted paths on stderr, so that is the findings channel.
nixfmt --check "${nix_files[@]}" >/dev/null 2>"$ERRLOG"
rc=$?
unformatted=$(cat "$ERRLOG")
if [ -n "$unformatted" ]; then
  echo "$unformatted"
  while IFS= read -r line; do
    file=${line%%:*}
    [ -f "$file" ] || continue
    count nixfmt error
    annotate error "$file" 1 1 nixfmt "Not formatted. Run 'nixfmt $file'."
  done <<<"$unformatted"
elif [ "$rc" -ne 0 ]; then
  broke nixfmt "$rc"
else
  echo "formatting ok"
fi

section statix
statix_out=$(statix check . --format errfmt 2>"$ERRLOG")
rc=$?
if [ -s "$ERRLOG" ]; then
  broke statix "$rc"
elif [ -n "$statix_out" ]; then
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
else
  echo "no anti-patterns"
fi

section deadnix
dead_json=$(deadnix --output-format json . 2>"$ERRLOG")
rc=$?
dead_out=$(jq -r '.file as $f | .results[] | "\($f)\t\(.line)\t\(.column)\t\(.message)"' <<<"$dead_json" 2>/dev/null)
if [ -s "$ERRLOG" ]; then
  broke deadnix "$rc"
elif [ -n "$dead_out" ]; then
  while IFS=$'\t' read -r file ln col msg; do
    [ -z "$file" ] && continue
    # The { config, lib, pkgs, ... } module signature is convention, not a
    # defect, so it is reported without blocking. Other dead code blocks.
    case $msg in
      "Unused lambda pattern"*) level=info ;;
      *) level=warning ;;
    esac
    printf '%s:%s:%s: %s: %s\n' "${file#./}" "$ln" "$col" "$level" "$msg"
    count deadnix "$level"
    annotate "$level" "${file#./}" "$ln" "$col" deadnix "$msg"
  done <<<"$dead_out"
elif [ "$rc" -ne 0 ]; then
  broke deadnix "$rc"
else
  echo "no dead code"
fi

section shellcheck
sc_json=$(shellcheck --severity=style --format=json "${sh_files[@]}" 2>"$ERRLOG")
rc=$?
sc_out=$(jq -r '.[] | "\(.file)\t\(.line)\t\(.column)\t\(.level)\t[SC\(.code)] \(.message)"' <<<"$sc_json" 2>/dev/null)
if [ -s "$ERRLOG" ]; then
  broke shellcheck "$rc"
elif [ -n "$sc_out" ]; then
  while IFS=$'\t' read -r file ln col level msg; do
    [ -z "$file" ] && continue
    printf '%s:%s:%s: %s: %s\n' "${file#./}" "$ln" "$col" "$level" "$msg"
    [ "$level" = style ] && level=info
    count shellcheck "$level"
    annotate "$level" "${file#./}" "$ln" "$col" shellcheck "$msg"
  done <<<"$sc_out"
elif [ "$rc" -gt 1 ]; then
  # Exit 1 means findings; 2 or above means it could not run.
  broke shellcheck "$rc"
else
  echo "no findings"
fi

section nix-eval
if [ "${LINT_SKIP_EVAL:-0}" = 1 ]; then
  # Without a measurement there is nothing to compare, so drop the baseline
  # rather than report a fall to zero.
  unset 'BASE[nix-eval.error]' 'BASE[nix-eval.warning]' 'BASE[nix-eval.info]'
  echo "skipped"
else
  # Module-system warnings are emitted only on a cold evaluation, so the eval
  # cache is bypassed to make them show up every run rather than once.
  eval_out=$(nix flake check --no-build --option eval-cache false 2>&1)
  rc=$?
  eval_warnings=$(grep '^evaluation warning:' <<<"$eval_out" || true)
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$eval_out" | tail -20
    count nix-eval error
    printf '::error title=nix-eval::flake check failed\n'
  elif [ -n "$eval_warnings" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      msg=${line#evaluation warning: }
      printf 'info: %s\n' "$msg"
      count nix-eval info
      printf '::notice title=nix-eval::%s\n' "$msg"
    done <<<"$eval_warnings"
  else
    echo "no evaluation warnings"
  fi
fi

total_err=0 total_warn=0 total_info=0
for t in "${TOOLS[@]}"; do
  total_err=$((total_err + ERR[$t]))
  total_warn=$((total_warn + WARN[$t]))
  total_info=$((total_info + INFO[$t]))
done

section summary
printf '%s Nix files, %s shell files\n\n' "${#nix_files[@]}" "${#sh_files[@]}"
printf '%-12s %12s %12s %12s\n' tool errors warnings info
for t in "${TOOLS[@]}"; do
  printf '%-12s %12s %12s %12s\n' "$t" \
    "$(delta "$t.error" "${ERR[$t]}")" \
    "$(delta "$t.warning" "${WARN[$t]}")" \
    "$(delta "$t.info" "${INFO[$t]}")"
done
printf '%-12s %12s %12s %12s\n' total \
  "$(delta total.error "$total_err")" \
  "$(delta total.warning "$total_warn")" \
  "$(delta total.info "$total_info")"

if [ -n "${LINT_COUNTS:-}" ]; then
  {
    for t in "${TOOLS[@]}"; do
      printf '%s %s %s %s\n' "$t" "${ERR[$t]}" "${WARN[$t]}" "${INFO[$t]}"
    done
    printf 'total %s %s %s\n' "$total_err" "$total_warn" "$total_info"
  } >"$LINT_COUNTS"
fi

if [ -n "${LINT_SUMMARY:-}" ]; then
  {
    if [ "$total_err" -eq 0 ] && [ "$total_warn" -eq 0 ]; then
      printf '**Clean** — no errors or warnings'
      [ "$total_info" -gt 0 ] && printf ', %s info-level finding(s)' "$total_info"
      printf '.\n\n'
    else
      printf '**%s error(s), %s warning(s).**\n\n' "$total_err" "$total_warn"
    fi
    printf '| Tool | Errors | Warnings | Info |\n|---|--:|--:|--:|\n'
    for t in "${TOOLS[@]}"; do
      printf '| %s | %s | %s | %s |\n' "$t" \
        "$(delta "$t.error" "${ERR[$t]}")" \
        "$(delta "$t.warning" "${WARN[$t]}")" \
        "$(delta "$t.info" "${INFO[$t]}")"
    done
    printf '| **Total** | **%s** | **%s** | **%s** |\n\n' \
      "$(delta total.error "$total_err")" \
      "$(delta total.warning "$total_warn")" \
      "$(delta total.info "$total_info")"
    [ "${#BASE[@]}" -gt 0 ] && printf 'Change against the base branch in brackets. '
    printf 'Scanned %s Nix files and %s shell files.\n' \
      "${#nix_files[@]}" "${#sh_files[@]}"
  } >"$LINT_SUMMARY"
fi

[ "$total_err" -eq 0 ] && [ "$total_warn" -eq 0 ]
