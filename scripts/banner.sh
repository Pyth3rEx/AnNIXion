#!/usr/bin/env bash
# Render assets/branding/banner.png — the lockup.
#
# Generated rather than drawn, for the same reason the design board is: the
# banner then cannot show an identity that is not the documented one. Chromium
# is the renderer because the lockup is CSS; it is fetched on demand and never
# enters the system closure. Rules: docs/visual-identity.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WIDTH=${WIDTH:-1920}
HEIGHT=${HEIGHT:-520}
OUT="$ROOT/assets/branding/banner.png"
MARK="$ROOT/assets/branding/AnNIXion.png"

chromium=${CHROMIUM:-$(nix build --no-link --print-out-paths nixpkgs#chromium)/bin/chromium}

# The face is pinned to the store rather than taken from whatever fontconfig
# has installed: a machine without JetBrains Mono would otherwise render the
# lockup in a fallback and the difference is not obvious until it ships.
font=$(nix build --no-link --print-out-paths nixpkgs#nerd-fonts.jetbrains-mono)
fontdir=$(mktemp -d -t annixion-fonts-XXXXXX)
fontcfg="$fontdir/fonts.conf"
cat > "$fontcfg" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>$font/share/fonts</dir>
  <cachedir>$fontdir/cache</cachedir>
</fontconfig>
EOF

html=$(mktemp -t annixion-banner-XXXXXX.html)
shot=$(mktemp -d -t annixion-shot-XXXXXX)
trap 'rm -rf "$html" "$shot" "$fontdir"' EXIT

python3 scripts/banner.py "$MARK" "$html" "$WIDTH" "$HEIGHT"

FONTCONFIG_FILE="$fontcfg" "$chromium" --headless --disable-gpu --no-sandbox \
  --hide-scrollbars --force-device-scale-factor=1 \
  --virtual-time-budget=5000 \
  --window-size="$WIDTH,$HEIGHT" \
  --screenshot="$shot/banner.png" "file://$html" 2>/dev/null

if [ ! -s "$shot/banner.png" ]; then
  echo "banner: chromium produced nothing" >&2
  exit 1
fi

# ── Render gate ────────────────────────────────────────────────────────────
# A missing font, a broken data: URI or a CSS typo all produce a PNG of the
# right size that is simply wrong, and none of them fail the render. Assert
# the two things that prove the lockup actually drew: the signature red is on
# the canvas, and the canvas is not overwhelmingly one flat colour.
python3 - "$shot/banner.png" "$WIDTH" "$HEIGHT" <<'PY'
import struct, sys, zlib

path, want_w, want_h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
raw = open(path, "rb").read()
if raw[:8] != b"\x89PNG\r\n\x1a\n":
    sys.exit("banner: not a PNG")

pos, idat, w, h, depth, colour = 8, b"", None, None, None, None
while pos < len(raw):
    ln = struct.unpack(">I", raw[pos:pos + 4])[0]
    typ = raw[pos + 4:pos + 8]
    body = raw[pos + 8:pos + 8 + ln]
    if typ == b"IHDR":
        w, h, depth, colour = (*struct.unpack(">II", body[:8]), body[8], body[9])
    elif typ == b"IDAT":
        idat += body
    pos += 12 + ln

if (w, h) != (want_w, want_h):
    sys.exit(f"banner: rendered {w}x{h}, wanted {want_w}x{want_h}")
if depth != 8 or colour not in (2, 6):
    sys.exit(f"banner: unexpected PNG format (depth {depth}, colour type {colour})")

stride = 4 if colour == 6 else 3
data = zlib.decompress(idat)
# Undo the per-scanline filters so the pixels can be counted.
out = bytearray()
prev = bytearray(w * stride)
i = 0
for _ in range(h):
    f = data[i]; i += 1
    line = bytearray(data[i:i + w * stride]); i += w * stride
    for x in range(len(line)):
        a = line[x - stride] if x >= stride else 0
        b = prev[x]
        c = prev[x - stride] if x >= stride else 0
        if f == 1: line[x] = (line[x] + a) & 0xFF
        elif f == 2: line[x] = (line[x] + b) & 0xFF
        elif f == 3: line[x] = (line[x] + (a + b) // 2) & 0xFF
        elif f == 4:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
    out += line
    prev = line

red = ink = 0
total = w * h
for p in range(0, len(out), stride):
    r, g, b = out[p], out[p + 1], out[p + 2]
    if r > 150 and g < 90 and b < 110:
        red += 1
    if r > 40 or g > 40 or b > 40:
        ink += 1

pct_red, pct_ink = 100 * red / total, 100 * ink / total
if red == 0:
    sys.exit("banner: no signature red on the canvas — the lockup did not draw")
if pct_ink < 1:
    sys.exit(f"banner: only {pct_ink:.2f}% of the canvas has ink — near-blank render")
print(f"banner: {w}x{h}, {pct_ink:.1f}% ink, {pct_red:.2f}% signature red")
PY

mv "$shot/banner.png" "$OUT"
printf 'assets/branding/banner.png: %s\n' "$(du -h "$OUT" | cut -f1)"
