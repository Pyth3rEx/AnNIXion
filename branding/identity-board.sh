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
trap 'rm -f "$html"' EXIT

python3 branding/identity-board.py "$icons/share/icons/AnNIXion/scalable/apps" "$html"

"$chromium" --headless --disable-gpu --no-sandbox \
  --no-pdf-header-footer --print-to-pdf-no-header \
  --print-to-pdf="$ROOT/docs/visual-identity.pdf" "file://$html"

printf 'docs/visual-identity.pdf: %s\n' "$(du -h docs/visual-identity.pdf | cut -f1)"
