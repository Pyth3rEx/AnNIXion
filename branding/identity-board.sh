#!/usr/bin/env bash
# Render docs/visual-identity.pdf — the design board.
#
# Marks come out of a freshly built icon theme rather than being redrawn for
# print, so the board cannot describe a set that is not the one shipping.
# Chromium is the renderer because the board is CSS paged media; it is fetched
# on demand and never enters the system closure.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

icons=$(nix build --no-link --print-out-paths --impure --expr \
  'let pkgs = import <nixpkgs> {}; in import ./home/icons { inherit pkgs; lib = pkgs.lib; }')

chromium=${CHROMIUM:-$(nix build --no-link --print-out-paths nixpkgs#chromium)/bin/chromium}

html=$(mktemp -t annixion-board-XXXXXX.html)
probe=$(mktemp -t annixion-probe-XXXXXX.html)
trap 'rm -f "$html" "$probe"' EXIT

python3 branding/identity-board.py "$icons/share/icons/AnNIXion/scalable/apps" "$html"

# ── Overflow gate ──────────────────────────────────────────────────────────
# Every page is a fixed 297x210mm box with overflow:hidden, so a page that
# outgrows itself loses its last paragraph silently and the PDF still builds.
# Measure each page's content box in the browser before committing to print.
python3 - "$html" "$probe" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
probe = '''<script>
window.addEventListener('load', function () {
  var out = [];
  document.querySelectorAll('.page').forEach(function (el, i) {
    var pb = el.querySelector('.pb');
    if (!pb) return;
    var deepest = 0;
    pb.querySelectorAll('*').forEach(function (c) {
      var b = c.getBoundingClientRect().bottom;
      if (b > deepest) { deepest = b; }
    });
    var by = Math.max(pb.scrollHeight - pb.clientHeight,
                      Math.round(deepest - pb.getBoundingClientRect().bottom));
    if (by > 1) { out.push('page ' + (i + 1) + ' overflows by ' + by + 'px'); }
  });
  // Marker assembled at runtime so this source cannot match the grep.
  document.title = ['PRO' + 'BE', '[', out.join(' ; '), ']'].join('');
});
</script>'''
open(dst, 'w').write(open(src).read().replace('</body>', probe + '</body>'))
PY

# Angle brackets are escaped in a DOM dump, so the marker uses square ones.
title=$("$chromium" --headless --disable-gpu --no-sandbox --virtual-time-budget=5000 \
  --dump-dom "file://$probe" 2>/dev/null | grep -o 'PROBE\[[^]]*\]' || true)

if [ -z "$title" ]; then
  echo "identity-board: the overflow probe did not run; refusing to print blind"
  exit 1
fi
report=${title#PROBE[}
report=${report%]}

if [ -n "$report" ]; then
  printf 'identity-board: content does not fit the page and would be clipped:\n  %s\n' "$report"
  exit 1
fi

"$chromium" --headless --disable-gpu --no-sandbox \
  --no-pdf-header-footer --print-to-pdf-no-header \
  --print-to-pdf="$ROOT/docs/visual-identity.pdf" "file://$html"

printf 'docs/visual-identity.pdf: %s, %s pages, no overflow\n' \
  "$(du -h docs/visual-identity.pdf | cut -f1)" \
  "$(grep -o 'class="page' "$html" | wc -l)"
