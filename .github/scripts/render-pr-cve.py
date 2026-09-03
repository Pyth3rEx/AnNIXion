#!/usr/bin/env python3
"""Render the CVE comment for a pull request, from a scan of what it adds.

The weekly scan answers "what is known about the release". This answers a
narrower question a reviewer actually has in front of them: does this branch
introduce a package with a known CVE. So the scan output is filtered down to the
packages closure-added.py found -- the scan covers their dependencies too, and
those are the base branch's problem, already on the published page.

Grading, escaping and the classification buckets come from
render-security-pages.py. A second severity scale that disagreed with the
published one would be worse than no comment at all.

  render-pr-cve.py --added JSON --triage CSV [--vulns CSV] --out FILE

Exit 0 when nothing added is flagged above the threshold, 1 when something is,
2 on a usage error. The caller decides whether that fails the check.
"""

import argparse
import importlib.util
import os
import sys
from collections import defaultdict

MARKER = "<!-- annixion-pr-cve -->"


def renderer():
    """The published pages' renderer, imported for its grading."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "render-security-pages.py")
    spec = importlib.util.spec_from_file_location("render_security_pages", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


pages = renderer()


def added_index(packages):
    """{lowercased name: record}. vulnxscan reports CPE product names, which
    match the attribute name in case as well as spelling often enough to key on
    directly and not always enough to rely on."""
    return {p["name"].lower(): p for p in packages}


def scope(rows, index):
    """Only the findings against a package this branch adds."""
    keep = []
    for row in rows:
        pkg = (row.get("package") or "").strip().lower()
        if pkg in index:
            keep.append((row, index[pkg]))
    return keep


def version_cell(row, pkg):
    installed = pages.esc(row.get("version_local") or pkg["version"])
    if pkg["status"] == "new":
        return f"`{installed}` · new"
    was = ", ".join(f"`{pages.esc(v)}`" for v in pkg["was"]) or "—"
    return f"`{installed}` · was {was}"


def fix_cell(row):
    column = pages.FIX_COLUMN.get((row.get("classify") or "").strip())
    if not column:
        return "—"
    version = (row.get(column) or "").strip()
    return f"`{pages.esc(version)}`" if version else "—"


def table(rows, provenance, engine_by_key):
    out = ["| CVE | CVSS | Package | In this branch | Fixed in | Maintainers | Engines |",
           "|---|---|---|---|---|---|---|"]
    for row, pkg in rows:
        name = row.get("package", "")
        entry = provenance.get(name)
        if name in provenance and entry is None:
            people = "*unresolved*"
        else:
            people = pages.maintainers_cell((entry or {}).get("maintainers") or [])
        out.append("| " + " | ".join([
            f"[{row.get('vuln_id', '')}]({row.get('url', '')})",
            pages.sev_cell(row),
            f"`{pages.esc(name)}`",
            version_cell(row, pkg),
            fix_cell(row),
            people,
            engine_by_key.get((row.get("vuln_id", ""), name), "—"),
        ]) + " |")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--added", required=True, help="JSON from closure-added.py")
    ap.add_argument("--triage", help="vulns.triage.csv from vulnxscan --triage")
    ap.add_argument("--vulns", help="vulns.csv, for the engine column")
    ap.add_argument("--provenance", help="JSON from package-provenance.sh")
    ap.add_argument("--out", required=True)
    ap.add_argument("--threshold", type=float, default=9.0,
                    help="CVSS at or above which this exits 1 (default 9.0)")
    ap.add_argument("--base-ref", default="")
    args = ap.parse_args()

    if not os.path.exists(args.added):
        print(f"render-pr-cve: {args.added} does not exist", file=sys.stderr)
        return 2

    packages = pages.read_json(args.added, [])
    index = added_index(packages)

    # vulnxscan writes no triage file when it found nothing, and the scan is
    # skipped outright when the branch adds nothing. Either way an absent file
    # means no findings — the caller has already failed the job if the scan
    # itself did not run to completion.
    def optional(path, read, empty):
        if not path or not os.path.exists(path):
            if path:
                print(f"render-pr-cve: {path} is absent, reading it as empty", file=sys.stderr)
            return empty
        return read(path)

    triage = optional(args.triage, pages.read_csv, [])
    engine_by_key = {(r.get("vuln_id", ""), r.get("package", "")): pages.engines(r)
                     for r in optional(args.vulns, pages.read_csv, [])}
    provenance = optional(args.provenance, lambda p: pages.read_json(p, {}), {})

    flagged = scope(triage, index)
    buckets = defaultdict(list)
    known = {c[0] for c in pages.CLASSES}
    for row, pkg in flagged:
        raw = (row.get("classify") or "").strip()
        buckets[raw if raw in known else "unclassified"].append((row, pkg))
    for rows in buckets.values():
        rows.sort(key=lambda t: (-(pages.severity(t[0]) or 0), t[0].get("package", "")))

    # Not-applicable findings do not gate anything: repology puts the packaged
    # version outside the affected range.
    gating = [t for key, rows in buckets.items() if key not in pages.FOLDED for t in rows]
    over = [t for t in gating
            if (pages.severity(t[0]) or 0) >= args.threshold]
    worst = max((t for t in gating if pages.severity(t[0]) is not None),
                key=lambda t: pages.severity(t[0]), default=None)

    new = [p for p in packages if p["status"] == "new"]
    changed = [p for p in packages if p["status"] == "changed"]
    against = f" against `{pages.esc(args.base_ref)}`" if args.base_ref else ""

    out = [MARKER, "## CVEs in what this branch adds", "",
           f"{len(new)} new package(s), {len(changed)} changed{against} · "
           f"{len(gating)} finding(s)"
           + (f" · worst {pages.sev_cell(worst[0])}" if worst else "")]
    out.append("")

    if not packages:
        out += ["Nothing new in the runtime closure. The published "
                "[security status](docs/security/README.md) still covers it all.", ""]
    elif not flagged:
        names = ", ".join(f"`{pages.esc(p['name'])}` `{pages.esc(p['version'])}`"
                          for p in sorted(packages, key=lambda p: p["name"])[:20])
        more = " …" if len(packages) > 20 else ""
        out += ["No known CVE against any of them:", "", names + more, ""]
    else:
        if over:
            worst_pkgs = ", ".join(sorted({f"`{pages.esc(t[0].get('package', ''))}`"
                                           for t in over}))
            out += [f"**{len(over)} finding(s) at CVSS {args.threshold:.1f} or above**, "
                    f"in {worst_pkgs}. This branch is what puts them on the "
                    "system.", ""]
        for key, heading, blurb in pages.CLASSES:
            rows = buckets.get(key) or []
            if not rows:
                continue
            if key in pages.FOLDED:
                out += ["<details>",
                        f"<summary><strong>{heading} ({len(rows)})</strong> — {blurb}</summary>", ""]
            else:
                out += [f"### {heading} ({len(rows)})", "", blurb, ""]
            out += table(rows, provenance, engine_by_key)
            out += ["", "</details>", ""] if key in pages.FOLDED else [""]

    out += ["<sub>Scanned only the packages this branch adds to the closure, not "
            "the whole system — the rest is covered by the weekly "
            "[CVE status](docs/security/README.md). Presence, not reachability.</sub>"]

    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out).rstrip() + "\n")

    print(f"{len(packages)} package(s) added, {len(gating)} finding(s), "
          f"{len(over)} at or above {args.threshold:.1f}", file=sys.stderr)
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
