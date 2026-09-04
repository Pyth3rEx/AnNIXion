#!/usr/bin/env python3
"""Exact ink bounds for every rendered mark.

A round cap or join reaches half a stroke width past the geometry, so a mark
whose path stops at the edge of the 24-unit canvas has that cap sliced flat by
the viewBox — which reads as a sharp, cut-off end rather than a drawn one. This
computes the real extent so the build can refuse to ship one.

Usage: mark-bbox.py <dir-of-svgs> [--quiet]
Exits non-zero if any mark's ink leaves the canvas.
"""
import sys, os, re, math

GRID = 24.0                       # the unit grid every mark is drawn on
NUM = re.compile(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
CMD = re.compile(r'([MmLlHhVvCcSsQqTtAaZz])')


def _cubic_extrema(p0, p1, p2, p3):
    """Parameter values in (0,1) where a cubic's derivative vanishes."""
    a = -p0 + 3 * p1 - 3 * p2 + p3
    b = 2 * (p0 - 2 * p1 + p2)
    c = p1 - p0
    ts = []
    if abs(a) < 1e-12:
        if abs(b) > 1e-12:
            ts.append(-c / b)
    else:
        disc = b * b - 4 * a * c
        if disc >= 0:
            r = math.sqrt(disc)
            ts += [(-b + r) / (2 * a), (-b - r) / (2 * a)]
    return [t for t in ts if 0 < t < 1]


def _cubic_at(p0, p1, p2, p3, t):
    u = 1 - t
    return u**3 * p0 + 3 * u**2 * t * p1 + 3 * u * t**2 * p2 + t**3 * p3


def path_points(d):
    """Every point the path actually reaches, curve extrema included."""
    toks = [t for t in CMD.split(d) if t.strip()]
    pts, cur, start, cmd = [], (0.0, 0.0), (0.0, 0.0), None
    prev_c2 = None          # second control point of the previous cubic
    prev_q1 = None          # control point of the previous quadratic
    i = 0
    while i < len(toks):
        t = toks[i]
        if CMD.fullmatch(t):
            cmd = t
            i += 1
            args = [float(x) for x in NUM.findall(toks[i])] if i < len(toks) and not CMD.fullmatch(toks[i]) else []
            if args:
                i += 1
        else:
            args = [float(x) for x in NUM.findall(t)]
            i += 1
            if cmd in ('M', 'm'):
                cmd = 'L' if cmd == 'M' else 'l'

        rel = cmd.islower()
        k = cmd.upper()
        n = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'S': 4, 'Q': 4, 'T': 2, 'Z': 0}[k]

        if k == 'Z':
            cur = start
            pts.append(cur)
            prev_c2 = prev_q1 = None
            continue

        for j in range(0, len(args), n):
            a = args[j:j + n]
            if len(a) < n:
                break
            if k == 'M':
                cur = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                start = cur
                pts.append(cur)
                prev_c2 = prev_q1 = None
                # subsequent coordinate pairs of an M are implicit L
                k, n, cmd = 'L', 2, ('l' if rel else 'L')
            elif k == 'L':
                cur = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                pts.append(cur)
                prev_c2 = prev_q1 = None
            elif k in ('H', 'V'):
                if k == 'H':
                    cur = (cur[0] + a[0], cur[1]) if rel else (a[0], cur[1])
                else:
                    cur = (cur[0], cur[1] + a[0]) if rel else (cur[0], a[0])
                pts.append(cur)
                prev_c2 = prev_q1 = None
            elif k in ('C', 'S'):
                if k == 'C':
                    c1 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                    c2 = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
                    end = (cur[0] + a[4], cur[1] + a[5]) if rel else (a[4], a[5])
                else:
                    c1 = (2 * cur[0] - prev_c2[0], 2 * cur[1] - prev_c2[1]) if prev_c2 else cur
                    c2 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                    end = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
                pts.append(end)
                for axis in (0, 1):
                    for tt in _cubic_extrema(cur[axis], c1[axis], c2[axis], end[axis]):
                        v = _cubic_at(cur[axis], c1[axis], c2[axis], end[axis], tt)
                        pts.append((v, cur[1]) if axis == 0 else (cur[0], v))
                cur, prev_c2, prev_q1 = end, c2, None
            elif k in ('Q', 'T'):
                if k == 'Q':
                    q1 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                    end = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
                else:
                    q1 = (2 * cur[0] - prev_q1[0], 2 * cur[1] - prev_q1[1]) if prev_q1 else cur
                    end = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                pts.append(end)
                # a quadratic is a cubic with these control points
                for axis in (0, 1):
                    c1 = cur[axis] + 2.0 / 3 * (q1[axis] - cur[axis])
                    c2 = end[axis] + 2.0 / 3 * (q1[axis] - end[axis])
                    for tt in _cubic_extrema(cur[axis], c1, c2, end[axis]):
                        v = _cubic_at(cur[axis], c1, c2, end[axis], tt)
                        pts.append((v, cur[1]) if axis == 0 else (cur[0], v))
                cur, prev_q1, prev_c2 = end, q1, None
    return pts


def view_box(svg):
    n = [float(v) for v in NUM.findall(re.search(r'viewBox="([^"]+)"', svg).group(1))]
    return n[0], n[1], n[0] + n[2], n[1] + n[3]


def mark_bounds(svg):
    """Ink bounds and raw geometry bounds for one rendered mark.

    A mark may carry several groups at different stroke widths — the knockout
    pass under a crossing symbol is the widest — so each group is measured with
    its own weight.
    """
    sx0 = sy0 = gx0 = gy0 = float('inf')
    sx1 = sy1 = gx1 = gy1 = float('-inf')
    for g in re.findall(r'<g\b[^>]*>.*?</g>', svg, re.S):
        half = float(re.search(r'stroke-width="([\d.]+)"', g).group(1)) / 2.0
        for d in re.findall(r'<path[^>]*\bd="([^"]+)"', g):
            for x, y in path_points(d):
                sx0, sy0 = min(sx0, x - half), min(sy0, y - half)
                sx1, sy1 = max(sx1, x + half), max(sy1, y + half)
                gx0, gy0 = min(gx0, x), min(gy0, y)
                gx1, gy1 = max(gx1, x), max(gy1, y)
        for c in re.findall(r'<circle[^>]*>', g):
            cx = float(re.search(r'cx="([-\d.]+)"', c).group(1))
            cy = float(re.search(r'cy="([-\d.]+)"', c).group(1))
            r = float(re.search(r'r="([-\d.]+)"', c).group(1))
            pad = 0.0 if 'stroke="none"' in c else half
            sx0, sy0 = min(sx0, cx - r - pad), min(sy0, cy - r - pad)
            sx1, sy1 = max(sx1, cx + r + pad), max(sy1, cy + r + pad)
            gx0, gy0 = min(gx0, cx - r), min(gy0, cy - r)
            gx1, gy1 = max(gx1, cx + r), max(gy1, cy + r)
    return (sx0, sy0, sx1, sy1), (gx0, gy0, gx1, gy1)


def main():
    d = sys.argv[1]
    quiet = "--quiet" in sys.argv
    clipped, offgrid = [], []
    n = 0
    for f in sorted(os.listdir(d)):
        if not f.startswith("annixion-") or not f.endswith(".svg"):
            continue
        n += 1
        name = f[len("annixion-"):-4]
        svg = open(os.path.join(d, f)).read()
        (ix0, iy0, ix1, iy1), (gx0, gy0, gx1, gy1) = mark_bounds(svg)
        vx0, vy0, vx1, vy1 = view_box(svg)

        # 1. no ink may fall outside the viewBox, or it is sliced flat
        over = []
        if ix0 < vx0 - 1e-6: over.append(f"left {vx0 - ix0:.2f}")
        if iy0 < vy0 - 1e-6: over.append(f"top {vy0 - iy0:.2f}")
        if ix1 > vx1 + 1e-6: over.append(f"right {ix1 - vx1:.2f}")
        if iy1 > vy1 + 1e-6: over.append(f"bottom {iy1 - vy1:.2f}")
        if over:
            clipped.append(f"{name}: ink clipped — {', '.join(over)}")

        # 2. geometry stays on the grid; the pad is for the stroke, not for
        #    drawing extra room
        out = []
        if gx0 < -1e-6: out.append(f"left {-gx0:.2f}")
        if gy0 < -1e-6: out.append(f"top {-gy0:.2f}")
        if gx1 > GRID + 1e-6: out.append(f"right {gx1 - GRID:.2f}")
        if gy1 > GRID + 1e-6: out.append(f"bottom {gy1 - GRID:.2f}")
        if out:
            offgrid.append(f"{name}: drawn off the {GRID:.0f}-unit grid — {', '.join(out)}")

    for label, rows in (("ink clipped by the viewBox", clipped),
                        ("geometry off the grid", offgrid)):
        if rows:
            print(f"mark-bbox: {len(rows)} mark(s), {label}:")
            for line in rows:
                print("  " + line)
    if clipped or offgrid:
        return 1
    if not quiet:
        print(f"mark-bbox: all {n} marks fit the grid and the padded canvas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
