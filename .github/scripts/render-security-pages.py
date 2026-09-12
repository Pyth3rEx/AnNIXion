#!/usr/bin/env python3
"""Render the published security pages from scan output.

Writes four files: an index, and one page each for findings, closure packages
and declared applications. Split because they are consulted separately -- an
index that carries 2346 package rows is not an index -- and because GitHub stops
rendering a blob somewhere past a megabyte.

Two structural decisions, both measured rather than assumed.

Findings are bucketed by triage classification, not by scanner agreement. Of 334
findings on the closure this was built against, 231 were seen by one engine, 103
by two, none by three. The most serious one in the tree is a sum=1, so a
"two scanners" rule deletes it.

Maintainer counts are reported next to CVE counts. An unmaintained package with
no findings is a supply-chain fact that no severity score carries.
"""

import argparse
import csv
import datetime
import json
import os
import sys
from collections import Counter, defaultdict

CLASSES = [
    ("fix_update_to_version_nixpkgs", "Fix in nixpkgs", "Packaged. Rebuild or bump the lock."),
    ("fix_update_to_version_upstream", "Fixed upstream", "Released, not yet in nixpkgs. Needs a nixpkgs PR."),
    ("fix_not_available", "No fix", "Disclosed, nothing released."),
    ("unclassified", "Unclassified", "repology could not resolve a version. Treated as unknown."),
    ("err_not_vulnerable_based_on_repology", "Not applicable", "Packaged version outside the affected range."),
]
FOLDED = {"err_not_vulnerable_based_on_repology"}
ACTIONABLE = {"fix_update_to_version_nixpkgs", "fix_update_to_version_upstream"}
FIX_COLUMN = {
    "fix_update_to_version_nixpkgs": "version_nixpkgs",
    "fix_update_to_version_upstream": "version_upstream",
}

BANDS = [
    (9.0, "Critical", "\U0001F534"),
    (7.0, "High", "\U0001F7E0"),
    (4.0, "Medium", "\U0001F7E1"),
    (0.1, "Low", "\U0001F7E2"),
]
UNGRADED = ("Ungraded", "\u26AA")
GRADES = [(n, d) for _, n, d in BANDS] + [UNGRADED]


def band(score):
    if score is None:
        return UNGRADED
    for floor, name, dot in BANDS:
        if score >= floor:
            return (name, dot)
    return UNGRADED


def severity(row):
    try:
        return float((row.get("severity") or "").strip())
    except ValueError:
        return None


def sev_cell(row):
    s = severity(row)
    _, dot = band(s)
    return f"{dot} {s:.1f}" if s is not None else f"{dot} —"


def esc(text):
    return str(text or "").replace("|", "\\|").replace("\n", " ")


def maintainers_cell(people, unresolved=False):
    """Every maintainer, linked. No truncation -- a hidden '+3' is unreachable,
    and reachability is the whole reason the column exists."""
    if unresolved:
        return "*unresolved*"
    if not people:
        return "**none**"
    out = []
    for m in people:
        gh, name = m.get("github"), esc(m.get("name"))
        out.append(f"[@{gh}](https://github.com/{gh})" if gh else (name or "?"))
    return " ".join(out)


NIXPKGS_REF = "nixos-26.05"


def origin(position):
    """Where a package is defined.

    meta.position points into the nixpkgs source for anything packaged upstream
    and into this repository for anything defined here. Without the distinction
    every annixion-* helper counts as an unmaintained dependency, which is both
    wrong and flattering in the wrong direction -- it inflates a number we quote.
    """
    if not position:
        return ("unknown", "")
    _, _, tail = position.partition("-source/")
    if not tail:
        return ("unknown", "")
    path, _, line = tail.partition(":")
    if path.startswith("pkgs/"):
        anchor = f"#L{line}" if line.isdigit() else ""
        return ("nixpkgs", f"https://github.com/NixOS/nixpkgs/blob/{NIXPKGS_REF}/{path}{anchor}")
    return ("local", path)


def read_csv(path):
    if not path:
        return []
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def read_json(path, default):
    if not path:
        return default
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def engines(row):
    found = [n for n in ("vulnix", "grype", "osv")
             if (row.get(n) or "").strip() not in ("", "0", "False", "false")]
    return ", ".join(found) if found else "—"


def meta_property(sbom, name):
    for prop in (sbom.get("metadata") or {}).get("properties") or []:
        if prop.get("name") == name:
            return prop.get("value") or ""
    return ""


def grade_table(rows_by_label, out):
    out.append("| | " + " | ".join(f"{d} {n}" for n, d in GRADES) + " | Total |")
    out.append("|---|" + "---:|" * (len(GRADES) + 1))
    for label, rows, strong in rows_by_label:
        counts = Counter(band(severity(r))[0] for r in rows)
        b = "**" if strong else ""
        cells = " | ".join(str(counts.get(n, 0)) for n, _ in GRADES)
        out.append(f"| {b}{label}{b} | {cells} | {b}{len(rows)}{b} |")


def write(path, lines):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--triage", required=True)
    ap.add_argument("--vulns")
    ap.add_argument("--provenance", help="JSON from package-provenance.sh")
    ap.add_argument("--apps", help="JSON from installed-apps.sh")
    ap.add_argument("--sbom", help="runtime CycloneDX SBOM, for the closure package list")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--version", default="")
    ap.add_argument("--repo", default="Pyth3rEx/AnNIXion")
    ap.add_argument("--coverage", choices=("full", "reduced"), default="full")
    ap.add_argument("--generated", default="")
    args = ap.parse_args()

    triage = read_csv(args.triage)
    engine_by_key = {(r.get("vuln_id", ""), r.get("package", "")): engines(r)
                     for r in read_csv(args.vulns)}
    prov = read_json(args.provenance, {})
    apps = read_json(args.apps, [])
    sbom = read_json(args.sbom, {})

    os.makedirs(args.out_dir, exist_ok=True)
    generated = args.generated or datetime.datetime.now(
        datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    ver = args.version or "—"

    buckets = defaultdict(list)
    known = {c[0] for c in CLASSES}
    for row in triage:
        raw = (row.get("classify") or "").strip()
        buckets[raw if raw in known else "unclassified"].append(row)
    for rows in buckets.values():
        rows.sort(key=lambda r: (-(severity(r) or 0), r.get("package", ""), r.get("vuln_id", "")))

    findings_by_pkg = Counter(r.get("package", "") for r in triage)
    actionable_by_pkg = Counter(r.get("package", "")
                                for k in ACTIONABLE for r in buckets[k])
    total = len(triage)
    actionable = sum(len(buckets[k]) for k in ACTIONABLE)

    def maint_for(pkg):
        if pkg in prov and prov[pkg] is None:
            return maintainers_cell(None, unresolved=True)
        return maintainers_cell((prov.get(pkg) or {}).get("maintainers") or [])

    def lic_for(pkg):
        if pkg in prov and prov[pkg] is None:
            return "*unresolved*"
        return esc((prov.get(pkg) or {}).get("license")) or "*unstated*"

    closure_paths = meta_property(sbom, "annixion:closure_store_paths")
    closure_size = meta_property(sbom, "annixion:closure_size")
    components = sbom.get("components") or []
    pkg_rows = sorted(
        {(c.get("name", ""), c.get("version", "") or "") for c in components
         if not str(c.get("name", "")).endswith((".patch", ".diff"))},
        key=lambda t: (t[0].lower(), t[1]))

    app_origin = {a["name"]: origin(a.get("position", "")) for a in apps}
    app_local = sorted(n for n, (kind, _) in app_origin.items() if kind == "local")
    app_unmaintained = sorted(
        a["name"] for a in apps
        if not a.get("maintainers") and app_origin[a["name"]][0] != "local")
    upstream_apps = [a for a in apps if app_origin[a["name"]][0] != "local"]
    flagged_unmaintained = sorted(
        p for p in findings_by_pkg
        if prov.get(p) is not None and not (prov.get(p) or {}).get("maintainers"))

    # ── cves.md ──────────────────────────────────────────────────────
    out = [f"# CVEs — AnNIXion {ver}", "",
           f"`{generated}` · {total} findings · {actionable} actionable · "
           f"coverage `{args.coverage}`", "",
           "[← index](README.md) · [packages](packages.md) · [apps](apps.md)", ""]
    grade_table([(h, buckets[k], k in ACTIONABLE) for k, h, _ in CLASSES]
                + [("Total", triage, False)], out)
    out.append("")
    for key, heading, blurb in CLASSES:
        rows, n, fix = buckets[key], len(buckets[key]), FIX_COLUMN.get(key)
        if key in FOLDED:
            out += ["<details>", f"<summary><strong>{heading} ({n})</strong> — {blurb}</summary>", ""]
        else:
            out += [f"## {heading} ({n})", "", blurb, ""]
        if rows:
            out.append("| CVE | CVSS | Package | Installed | "
                       + ("Fixed in | " if fix else "") + "Licence | Maintainers | Engines |")
            out.append("|---|---|---|---|" + ("---|" if fix else "") + "---|---|---|")
            for r in rows:
                pkg = r.get("package", "")
                cells = [f"[{r.get('vuln_id','')}]({r.get('url','')})", sev_cell(r),
                         f"`{esc(pkg)}`", f"`{esc(r.get('version_local',''))}`"]
                if fix:
                    v = (r.get(fix) or "").strip()
                    cells.append(f"`{esc(v)}`" if v else "—")
                cells += [lic_for(pkg), maint_for(pkg),
                          engine_by_key.get((r.get("vuln_id", ""), pkg), "—")]
                out.append("| " + " | ".join(cells) + " |")
        else:
            out.append("*None.*")
        out += ["", "</details>", ""] if key in FOLDED else [""]
    write(os.path.join(args.out_dir, "cves.md"), out)

    # ── packages.md ──────────────────────────────────────────────────
    out = [f"# Packages — AnNIXion {ver}", "",
           f"`{generated}` · {len(pkg_rows)} packages in the installed closure"
           + (f" · {closure_paths} store paths · {closure_size}" if closure_paths else ""), "",
           "[← index](README.md) · [CVEs](cves.md) · [apps](apps.md)", "",
           "Everything on a running system, including transitive dependencies "
           "nobody chose directly. `CVEs` counts findings against that package; "
           "`Act.` counts the ones with a fix available.", "",
           "| Package | Version | Licence | Maintainers | CVEs | Act. |",
           "|---|---|---|---|---:|---:|"]
    for name, version in pkg_rows:
        n, a = findings_by_pkg.get(name, 0), actionable_by_pkg.get(name, 0)
        out.append(f"| `{esc(name)}` | `{esc(version)}` | {lic_for(name)} | "
                   f"{maint_for(name)} | {n or ''} | {a or ''} |")
    write(os.path.join(args.out_dir, "packages.md"), out)

    # ── apps.md ──────────────────────────────────────────────────────
    out = [f"# Installed applications — AnNIXion {ver}", "",
           f"`{generated}` · {len(apps)} declared · {len(upstream_apps)} from nixpkgs "
           f"({len(app_unmaintained)} unmaintained) · {len(app_local)} defined in this repo", "",
           "[← index](README.md) · [CVEs](cves.md) · [packages](packages.md)", "",
           "What `environment.systemPackages` asks for — the packages somebody "
           "chose. The rest of the closure arrived transitively; see "
           "[packages.md](packages.md).", "",
           "| Application | Version | What it is | Licence | Maintainers | Defined in | CVEs |",
           "|---|---|---|---|---|---|---:|"]
    for a in sorted(apps, key=lambda x: x["name"].lower()):
        n = findings_by_pkg.get(a["name"], 0)
        home = a.get("homepage") or ""
        label = f"[`{esc(a['name'])}`]({home})" if home else f"`{esc(a['name'])}`"
        kind, where = app_origin[a["name"]]
        if kind == "nixpkgs":
            source = f"[nixpkgs]({where})"
            who = maintainers_cell(a.get("maintainers") or [])
        elif kind == "local":
            source = f"`{esc(where)}`"
            who = "*this repo*"
        else:
            source = "—"
            who = maintainers_cell(a.get("maintainers") or [])
        out.append(f"| {label} | `{esc(a.get('version'))}` | {esc(a.get('description'))} | "
                   f"{esc(a.get('license')) or '*unstated*'} | {who} | {source} | {n or ''} |")
    write(os.path.join(args.out_dir, "apps.md"), out)

    # ── README.md ────────────────────────────────────────────────────
    def worst(rows):
        scored = [r for r in rows if severity(r) is not None]
        return max(scored, key=severity) if scored else None

    wa = worst([r for k in ACTIONABLE for r in buckets[k]])
    wo = worst(triage)
    out = [f"# Security status — AnNIXion {ver}", "",
           f"`{generated}` · coverage `{args.coverage}`"
           + (f" · closure {closure_paths} store paths, {closure_size}" if closure_paths else ""),
           "", "Generated. Do not edit by hand.", "",
           "| Page | Contents |", "|---|---|",
           f"| [CVEs](cves.md) | {total} findings, **{actionable} actionable**, across {len(findings_by_pkg)} packages |",
           f"| [Packages](packages.md) | {len(pkg_rows)} in the installed closure |",
           f"| [Applications](apps.md) | {len(apps)} declared in `systemPackages` |", "",
           "## Findings by severity", ""]
    grade_table([(f"[{h}](cves.md)", buckets[k], k in ACTIONABLE) for k, h, _ in CLASSES]
                + [("Total", triage, False)], out)
    out += ["", "## Highest", "", "| | CVE | CVSS | Package | Class |", "|---|---|---|---|---|"]
    for label, r, cls in (("Actionable", wa, "has a fix"), ("Any", wo, "including not-applicable")):
        if r is None:
            out.append(f"| {label} | — | — | — | — |")
            continue
        name, dot = band(severity(r))
        out.append(f"| {label} | [{r.get('vuln_id','')}]({r.get('url','')}) | "
                   f"{dot} {severity(r):.1f} {name} | `{esc(r.get('package',''))}` | {cls} |")
    out += ["", "## Maintainer coverage", "",
            "Packages nobody in nixpkgs has signed up for. A fix landing upstream "
            "does not reach us unless somebody here notices. Packages defined in "
            "this repository are counted separately — they are ours, not orphaned.", "",
            "| | Count |", "|---|---:|",
            f"| nixpkgs applications with no maintainer | {len(app_unmaintained)} / {len(upstream_apps)} |",
            f"| Applications defined in this repo | {len(app_local)} |",
            f"| Flagged packages with no maintainer | {len(flagged_unmaintained)} / {len(findings_by_pkg)} |", ""]
    if flagged_unmaintained:
        out += ["Flagged and unmaintained: "
                + ", ".join(f"`{esc(p)}`" for p in flagged_unmaintained), ""]
    out += ["## Caveats", ""]
    if args.coverage == "reduced":
        out.append("- Scanned from a stored SBOM, so `vulnix` did not run — it needs "
                   "live store paths. It is the only engine that sees some findings.")
    else:
        out.append("- Three engines, low overlap: 89 CVEs common to vulnix and grype "
                   "out of 458 and 192. The `Engines` column says which saw what.")
    out += ["- Presence, not reachability. Services `hardening.nix` disables still appear.",
            "- ~13% of CPEs sbomnix emits are malformed and skipped by grype, systemd among them.",
            "- Build-time inputs are excluded; they ship in the release's supply-chain page.",
            "- Exact for this tag only. The closure is pinned by `flake.lock`.", "",
            f"Report privately via [security advisories](https://github.com/{args.repo}/security/advisories)."]
    write(os.path.join(args.out_dir, "README.md"), out)

    print(f"wrote README.md cves.md packages.md apps.md to {args.out_dir}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
