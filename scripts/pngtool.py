#!/usr/bin/env python3
"""Just enough PNG to measure one. No dependency, so it runs anywhere nix does.

Used by banner.py to centre the mark on its ink rather than on its canvas, and
by banner-check.py to prove a render actually drew something.
"""
import struct
import zlib


def decode(path):
    """Return (width, height, stride, pixels) with the scanline filters undone."""
    raw = open(path, "rb").read()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")

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

    if depth != 8 or colour not in (2, 6):
        raise ValueError(f"{path}: expected 8-bit RGB or RGBA, got depth {depth} type {colour}")

    stride = 4 if colour == 6 else 3
    data = zlib.decompress(idat)
    out = bytearray()
    prev = bytearray(w * stride)
    i = 0
    for _ in range(h):
        f = data[i]
        i += 1
        line = bytearray(data[i:i + w * stride])
        i += w * stride
        if f:
            for x in range(len(line)):
                a = line[x - stride] if x >= stride else 0
                b = prev[x]
                c = prev[x - stride] if x >= stride else 0
                if f == 1:
                    line[x] = (line[x] + a) & 0xFF
                elif f == 2:
                    line[x] = (line[x] + b) & 0xFF
                elif f == 3:
                    line[x] = (line[x] + (a + b) // 2) & 0xFF
                elif f == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        out += line
        prev = line
    return w, h, stride, out


def ink_bbox(w, h, stride, px, threshold=24):
    """Where the drawing actually is, which is not where the canvas is.

    Transparent pixels never count; opaque ones count once they are brighter
    than the ground. Returns (x0, y0, x1, y1) or None for an empty image.
    """
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        row = y * w * stride
        for x in range(w):
            p = row + x * stride
            if stride == 4 and px[p + 3] < 16:
                continue
            if px[p] > threshold or px[p + 1] > threshold or px[p + 2] > threshold:
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
    return None if x1 < 0 else (x0, y0, x1, y1)
