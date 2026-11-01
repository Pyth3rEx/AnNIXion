#!/usr/bin/env python3
"""Make an upstream SysReptor export pin-able.

SysReptor's published design and template packs are regenerated on every
upstream docs deploy, and each export mints fresh random UUIDs for the asset
records inside it. The archive bytes therefore change every few days while the
designs themselves do not, which makes a hash over the archive useless as a
pin: it fails within days, on a change that is not a change.

The importer matches an asset to its file by NAME — `<design-id>-assets/<name>`
— and never by the asset's own id, so that id can be derived instead of
carried. Deriving it, sorting the JSON and dropping the archive's timestamps
leaves a tree whose hash only moves when the content really does.

Used by catalog/tools/productivity/sysreptor.nix at fetch time; run it by hand
the same way to work out a new hash:

    scripts/sysreptor-canonicalise.py <dir>
    nix hash path --sri --type sha256 <dir>
"""
import json
import os
import sys
import uuid

NS = uuid.uuid5(uuid.NAMESPACE_URL, "annixion/sysreptor/assets")


def canonicalise(path):
    with open(path) as fh:
        doc = json.load(fh)

    # Both shapes appear: designs carry `assets`, templates carry `images`.
    for key in ("assets", "images"):
        for entry in doc.get(key) or []:
            if isinstance(entry, dict) and "name" in entry:
                entry["id"] = str(uuid.uuid5(NS, doc["id"] + "/" + entry["name"]))

    with open(path, "w") as fh:
        json.dump(doc, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write("\n")


def main(root):
    seen = 0
    for dirpath, _, filenames in os.walk(root):
        for name in sorted(filenames):
            if name.endswith(".json"):
                canonicalise(os.path.join(dirpath, name))
                seen += 1
    if not seen:
        raise SystemExit("canonicalise: no JSON documents under %s" % root)
    print("canonicalised %d documents" % seen, file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1])
