#!/usr/bin/env python3
"""Read Priority and Size out of an issue-form body.

Issue forms render as `### Heading` followed by the answer, and an unanswered
optional dropdown renders as `_No response_`. Only the leading token matters:
the options read `P1 — ...`, so `P1` is what reaches the board.

Reads BODY from the environment, writes `priority=` and `size=` lines for
GITHUB_OUTPUT. An unrecognised or missing answer yields an empty value, which
the workflow turns into no flag at all.
"""

import os
import re
import sys

VALID = {
    "priority": {"P0", "P1", "P2"},
    "size": {"XS", "S", "M", "L", "XL"},
}


def answer(body: str, heading: str) -> str:
    """First non-empty line under a `### <heading>` section."""
    pattern = re.compile(
        rf"^###\s+{re.escape(heading)}.*?$(.*?)(?=^###\s|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(body)
    if not match:
        return ""
    for line in match.group(1).splitlines():
        line = line.strip()
        if line:
            return line
    return ""


def token(value: str, field: str) -> str:
    if not value or value.startswith("_No response_"):
        return ""
    first = re.split(r"[\s—–-]", value.strip(), maxsplit=1)[0].strip()
    return first if first in VALID[field] else ""


def main() -> int:
    body = os.environ.get("BODY", "")
    for field, heading in (("priority", "Priority"), ("size", "Size")):
        print(f"{field}={token(answer(body, heading), field)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
