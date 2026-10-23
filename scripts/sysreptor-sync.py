#!/usr/bin/env python3
"""Reconcile a bundled pack against what an instance already holds.

SysReptor's importer mints a fresh id for every document it reads, so importing
a pack twice produces a second copy of everything in it rather than updating
what is there. The wrapper therefore used to record that a pack had been
imported and never look at it again — which made the first import the only one.
A design added to the pack afterwards could never reach an install that had
already run, and neither could a change to a design already there.

Reconciling by name fixes the first half: import only the documents whose name
the instance lacks. The second half needs an update in place, because the name
is already taken; `update-script` emits a program that rewrites the content of
the documents this repo owns, keeping their ids so projects using them keep
working.

Project packs are deliberately not reconciled. They are example reports, they
are expected to be deleted once read, and a name check would re-import one the
moment somebody tidied up.

    sysreptor-sync.py names-script
    sysreptor-sync.py names         <pack.tar.gz> <kind>
    sysreptor-sync.py filter        <pack.tar.gz> <kind> <names-file> <out.tar.gz>
    sysreptor-sync.py update-script <pack.tar.gz> <kind>
"""
import base64
import json
import os
import sys
import tarfile

KINDS = ("design", "template", "project")


def _docs(pack):
    """Yield (member-name, document) for every top-level JSON in the pack."""
    with tarfile.open(pack, "r:gz") as tar:
        for member in tar.getmembers():
            if not member.isfile() or not member.name.endswith(".json"):
                continue
            if member.name.count("/") > 1:  # inside an assets directory
                continue
            fh = tar.extractfile(member)
            if fh is None:
                continue
            yield member.name, json.load(fh)


def doc_name(doc):
    """The name the instance stores this document under, or None if the
    document is a dependency carried alongside the ones we are matching."""
    fmt = doc.get("format", "")
    if fmt.startswith("templates/"):
        for tr in doc.get("translations") or []:
            if tr.get("is_main"):
                return (tr.get("data") or {}).get("title")
        return None
    return doc.get("name")


def cmd_names(pack, kind):
    for _, doc in _docs(pack):
        name = doc_name(doc)
        if name:
            print(name)


def cmd_filter(pack, kind, names_file, out):
    have = set()
    if os.path.exists(names_file):
        with open(names_file, encoding="utf-8") as fh:
            have = {line.rstrip("\n") for line in fh if line.strip()}

    keep_members, kept_names = set(), []
    keep_prefixes = []
    for member_name, doc in _docs(pack):
        name = doc_name(doc)
        if name is None or name in have:
            continue
        keep_members.add(member_name)
        kept_names.append(name)
        # Assets and images sit in a directory named after the document id.
        # tarfile reports the directory member itself without its trailing
        # slash, so match that spelling too or the directory entry is dropped.
        did = doc.get("id")
        if did:
            for suffix in ("-assets", "-images"):
                keep_prefixes.append("./%s%s" % (did, suffix))

    if not kept_names:
        return 1

    with tarfile.open(pack, "r:gz") as src, tarfile.open(out, "w:gz") as dst:
        for member in src.getmembers():
            wanted = member.name in keep_members or any(
                member.name.startswith(p) for p in keep_prefixes)
            if not wanted:
                continue
            dst.addfile(member, src.extractfile(member) if member.isfile() else None)

    for name in sorted(kept_names):
        print(name, file=sys.stderr)
    return 0


#  The marker is what the test stub looks for to recognise a name query.
NAMES_PROGRAM = r'''
#  __ANNIXION_NAMES__
from sysreptor.pentests.models import ProjectType, FindingTemplate

print("__ANNIXION_NAMES_BEGIN__")
for n in (ProjectType.objects
          .filter(linked_project__isnull=True, linked_user__isnull=True)
          .values_list("name", flat=True)):
    print("design:" + (n or ""))
for t in FindingTemplate.objects.select_related("main_translation"):
    print("template:" + ((t.main_translation.data or {}).get("title") or ""))
print("__ANNIXION_NAMES_END__")
'''


def cmd_names_script():
    sys.stdout.write(NAMES_PROGRAM)
    return 0


UPDATE_PROGRAM = r'''
import base64, io, json, tarfile

from sysreptor.pentests.models import ProjectType, FindingTemplate

KIND = _KIND
updated, skipped = [], []

with tarfile.open(fileobj=io.BytesIO(base64.b64decode(_PACK)), mode="r:gz") as tar:
    for member in tar.getmembers():
        if not member.isfile() or not member.name.endswith(".json"):
            continue
        if member.name.count("/") > 1:
            continue
        doc = json.load(tar.extractfile(member))

        if KIND == "design":
            name = doc.get("name")
            row = ProjectType.objects.filter(
                name=name, linked_project__isnull=True, linked_user__isnull=True).first()
            if row is None:
                continue
            for field in ("report_template", "report_styles", "report_sections",
                          "finding_fields", "finding_ordering", "finding_grouping",
                          "report_preview_data", "default_notes", "tags",
                          "language", "status"):
                if field in doc:
                    setattr(row, field, doc[field])
            row.save()
            updated.append(name)

        elif KIND == "template":
            main = next((t for t in doc.get("translations") or [] if t.get("is_main")), None)
            if main is None:
                continue
            title = (main.get("data") or {}).get("title")
            row = (FindingTemplate.objects
                   .select_related("main_translation")
                   .filter(main_translation__data__title=title).first())
            if row is None:
                continue
            row.main_translation.data = main.get("data") or {}
            row.main_translation.save()
            row.tags = doc.get("tags") or []
            row.save()
            updated.append(title)

print("__ANNIXION_UPDATED__", len(updated))
for n in sorted(updated):
    print("   ", n)
'''


def cmd_update_script(pack, kind):
    with open(pack, "rb") as fh:
        blob = base64.b64encode(fh.read()).decode()
    sys.stdout.write('_KIND = %r\n' % kind)
    sys.stdout.write('_PACK = "%s"\n' % blob)
    sys.stdout.write(UPDATE_PROGRAM)
    return 0


def main(argv):
    if argv and argv[0] == "names-script":
        return cmd_names_script()
    if len(argv) < 3:
        sys.stderr.write(__doc__)
        return 2
    action, pack, kind = argv[0], argv[1], argv[2]
    if kind not in KINDS:
        sys.stderr.write("unknown pack kind %r\n" % kind)
        return 2
    if action == "names":
        cmd_names(pack, kind)
        return 0
    if action == "filter":
        return cmd_filter(pack, kind, argv[3], argv[4])
    if action == "update-script":
        return cmd_update_script(pack, kind)
    sys.stderr.write("unknown action %r\n" % action)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
