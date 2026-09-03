#!/usr/bin/env python3
"""What a pull request adds to the runtime closure.

Diffs two `nix path-info -r` listings by store path. What is only in the pull
request's closure is what the pull request introduces: a package the base branch
never carried, or a different version of one it did. Both matter to a scanner --
a bump lands a new CVE set as surely as a new dependency does.

Most of that difference is not a package. Any configuration change rewrites
`etc`, `system-path` and the system derivation itself, and each of those
references the whole closure -- handing one to a scanner scopes it straight back
to everything, which is the cost this scan exists to avoid. So a path has to
look like a package to be kept: a name and a version, and not one of the
generated names that always differ.

  closure-added.py --base LIST --pr LIST [--out-json F] [--out-paths F]

Emits JSON on stdout by default: one object per package, with the store paths
that carry it.
"""

import argparse
import json
import os
import re
import sys

STORE_PREFIX = "/nix/store/"
HASH_LEN = 32

# Generated per build and versioned, so the versioned-name rule below cannot
# drop them. Each references far more than itself.
GENERATED = (
    "nixos-system-",
    "initrd-",
    "linux-config-",
    "unit-",
    "etc-",
    "X-Restart-Triggers-",
    "nixos-generation-",
)

# Fetched sources, not packages: `foo-1.2.3.tar.gz` would otherwise parse as
# version `1.2.3.tar.gz`.
NOT_A_PACKAGE = (".patch", ".diff", ".tar.gz", ".tar.xz", ".tar.bz2", ".tgz", ".zip", ".drv")

VERSION = re.compile(r"^[0-9][0-9A-Za-z._+]*$")


def parse(path):
    """(name, version) for a store path, or None if it is not a package.

    The version is the first dash-separated component that starts with a digit;
    everything before it is the name. What follows is an output suffix (`-dev`)
    or a build revision, and dropping it is what folds a package's outputs into
    one entry.
    """
    if not path.startswith(STORE_PREFIX):
        return None
    base = path[len(STORE_PREFIX):].split("/", 1)[0]
    if len(base) <= HASH_LEN + 1 or base[HASH_LEN] != "-":
        return None
    name = base[HASH_LEN + 1:]
    if name.endswith(NOT_A_PACKAGE) or name.startswith(GENERATED):
        return None
    parts = name.split("-")
    for i, part in enumerate(parts[1:], start=1):
        if VERSION.match(part):
            return ("-".join(parts[:i]), part)
    return None


def read_paths(path):
    with open(path, encoding="utf-8") as fh:
        return [line.strip() for line in fh if line.strip()]


def index(paths):
    """{name: {version: [store paths]}} for everything that parses."""
    out = {}
    for p in paths:
        parsed = parse(p)
        if parsed is None:
            continue
        name, version = parsed
        out.setdefault(name, {}).setdefault(version, []).append(p)
    return out


def added(base, pr):
    base_index, pr_index = index(base), index(pr)
    base_paths = set(base)
    result = []
    for name in sorted(pr_index):
        for version in sorted(pr_index[name]):
            paths = sorted(set(pr_index[name][version]) - base_paths)
            if not paths:
                continue
            if name not in base_index:
                status, was = "new", []
            elif version in base_index[name]:
                # Same name and version, rebuilt under a different hash. A
                # scanner has nothing new to say about it.
                continue
            else:
                status, was = "changed", sorted(base_index[name])
            result.append({"name": name, "version": version,
                           "status": status, "was": was, "paths": paths})
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="nix path-info -r of the base closure")
    ap.add_argument("--pr", required=True, help="nix path-info -r of the pull request's closure")
    ap.add_argument("--out-json", help="write the package list here instead of stdout")
    ap.add_argument("--out-paths", help="write the store paths to scan here, one per line")
    ap.add_argument("--out-names", help="write the package names here, one per line")
    args = ap.parse_args()

    for f in (args.base, args.pr):
        if not os.path.exists(f):
            print(f"closure-added: {f} does not exist", file=sys.stderr)
            return 2

    packages = added(read_paths(args.base), read_paths(args.pr))

    text = json.dumps(packages, indent=2)
    if args.out_json:
        with open(args.out_json, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
    else:
        print(text)
    if args.out_paths:
        with open(args.out_paths, "w", encoding="utf-8") as fh:
            for pkg in packages:
                for p in pkg["paths"]:
                    fh.write(p + "\n")
    if args.out_names:
        with open(args.out_names, "w", encoding="utf-8") as fh:
            for name in sorted({p["name"] for p in packages}):
                fh.write(name + "\n")

    new = sum(1 for p in packages if p["status"] == "new")
    print(f"{len(packages)} package(s) added or changed, {new} new", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
