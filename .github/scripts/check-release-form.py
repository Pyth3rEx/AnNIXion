#!/usr/bin/env python3
"""Validate the changelog form of a release PR body (dev -> main).

The merged body becomes the GitHub Release notes, so it is checked like code.
Run locally against a draft:  python3 .github/scripts/check-release-form.py body.md
"""

import os
import re
import sys

SECTIONS = ("Added", "Changed", "Removed", "Fixed")
CLOSING_KEYWORDS = (
    "close",
    "closes",
    "closed",
    "fix",
    "fixes",
    "fixed",
    "resolve",
    "resolves",
    "resolved",
)

KNOWN_ISSUES_HEADING = "Known issues, not closed here"
CLOSES_HEADING = "Issues closed on merge"

HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")
BULLET_RE = re.compile(r"^\s*[-*+]\s+(.*)$")
NESTED_BULLET_RE = re.compile(r"^\s+[-*+]\s+")
VERSION_RE = re.compile(r"\*\*Version:\*\*\s*`([^`]+)`\s*(?:→|->)\s*`([^`]+)`")
ISSUE_RE = re.compile(r"(?<![\w/])#(\d+)\b")
CLOSING_RE = re.compile(
    r"\b(" + "|".join(CLOSING_KEYWORDS) + r")\b\s*:?\s+#(\d+)\b", re.IGNORECASE
)

errors: list[str] = []
notices: list[str] = []


def strip_blocks(text: str) -> str:
    """Drop fenced blocks and HTML comments — the template's guidance is a comment."""
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def strip_code(text: str) -> str:
    """Also drop inline code — an issue ref inside backticks is not a link."""
    return re.sub(r"`[^`\n]*`", "", strip_blocks(text))


def split_sections(lines: list[str]) -> list[tuple[str, list[str]]]:
    """Return [(heading, body lines)], with a leading '' block for the preamble."""
    blocks: list[tuple[str, list[str]]] = [("", [])]
    in_fence = False
    for line in lines:
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        heading = None if in_fence else HEADING_RE.match(line)
        if heading:
            blocks.append((heading.group(1).strip(), []))
        else:
            blocks[-1][1].append(line)
    return blocks


def check_structure(blocks: list[tuple[str, list[str]]]) -> None:
    headings = [h for h, _ in blocks]
    present = [s for s in SECTIONS if s in headings]
    if not present:
        errors.append(
            "No changelog section found. A release PR needs at least one of: "
            + ", ".join(f"## {s}" for s in SECTIONS)
            + "."
        )
    if "Upgrade notes" not in headings:
        errors.append(
            "Missing '## Upgrade notes'. Write 'None.' under it if there is nothing to do."
        )
    for heading in headings:
        # Catch near-misses that would silently skip the per-bullet checks.
        canonical = heading.strip().rstrip(":")
        for section in SECTIONS:
            if canonical.lower() == section.lower() and canonical != section:
                errors.append(f"Section heading '{heading}' must be exactly '## {section}'.")


def check_bullets(blocks: list[tuple[str, list[str]]]) -> None:
    for heading, body in blocks:
        if heading not in SECTIONS:
            continue
        seen = False
        in_fence = False
        for line in body:
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence or not line.strip():
                continue
            if NESTED_BULLET_RE.match(line):
                errors.append(
                    f"'## {heading}': nested bullet not allowed — one change per line.\n"
                    f"    {line.strip()[:90]}"
                )
                continue
            bullet = BULLET_RE.match(line)
            if not bullet:
                errors.append(
                    f"'## {heading}': every line must be a '- {heading}: ...' bullet.\n"
                    f"    {line.strip()[:90]}"
                )
                continue
            seen = True
            if not bullet.group(1).startswith(f"{heading}: "):
                errors.append(
                    f"'## {heading}': bullet must start with '{heading}: '.\n"
                    f"    {line.strip()[:90]}"
                )
        if not seen:
            errors.append(f"'## {heading}' is empty — remove the section or fill it in.")


def check_version(text: str) -> None:
    match = VERSION_RE.search(text)
    if not match:
        errors.append(
            "Missing the version footer. End the body with: **Version:** `OLD` → `NEW`"
        )
        return
    old, new = match.group(1), match.group(2)
    if old == new:
        errors.append(f"Version footer shows no bump: `{old}` → `{new}`.")
    if any(p in (old + new) for p in ("OLD", "NEW", "<", ">")):
        errors.append(f"Version footer still holds template placeholders: `{old}` → `{new}`.")


def check_issue_refs(blocks: list[tuple[str, list[str]]]) -> None:
    closing: set[str] = set()
    exempt: set[str] = set()
    referenced: set[str] = set()

    for heading, body in blocks:
        text = strip_code("\n".join(body))
        refs = set(ISSUE_RE.findall(text))
        referenced |= refs
        keyworded = {n for _, n in CLOSING_RE.findall(text)}
        if heading == KNOWN_ISSUES_HEADING:
            exempt |= refs
            for number in sorted(keyworded):
                errors.append(
                    f"#{number} is listed under '## {KNOWN_ISSUES_HEADING}' but carries a "
                    "closing keyword — it would close on merge. Drop the keyword or move it."
                )
        else:
            closing |= keyworded
            if heading == CLOSES_HEADING:
                for number in sorted(refs - keyworded):
                    errors.append(
                        f"#{number} sits under '## {CLOSES_HEADING}' without a closing "
                        f"keyword. Write 'Closes #{number}' so GitHub links it."
                    )

    for number in sorted(referenced - closing - exempt, key=int):
        errors.append(
            f"#{number} is referenced with no closing keyword. Either write "
            f"'Closes #{number}', list it under '## {KNOWN_ISSUES_HEADING}', or link the "
            "full URL if it is a merged PR."
        )

    if not closing:
        notices.append(
            "No issue will close on merge. That is fine for a release that fixes no "
            f"tracked issue — otherwise add a '## {CLOSES_HEADING}' section."
        )


def read_body(argv: list[str]) -> str:
    if len(argv) > 1:
        with open(argv[1], encoding="utf-8") as handle:
            return handle.read()
    body = os.environ.get("PR_BODY")
    if body is not None:
        return body
    return sys.stdin.read()


def main() -> int:
    body = read_body(sys.argv).replace("\r\n", "\n")
    if not body.strip():
        print("::error::The PR body is empty — it becomes the release notes on merge.")
        return 1

    lines = body.split("\n")
    blocks = split_sections(lines)

    check_structure(blocks)
    check_bullets(blocks)
    check_version(strip_blocks(body))
    check_issue_refs(blocks)

    annotate = bool(os.environ.get("GITHUB_ACTIONS"))
    for notice in notices:
        print(f"::notice::{notice}" if annotate else f"note: {notice}")
    for error in errors:
        first, _, rest = error.partition("\n")
        print(f"::error::{first}" if annotate else f"error: {first}")
        if rest:
            print(rest)

    if errors:
        print(
            f"\n{len(errors)} problem(s) in the PR body. "
            "See .github/RELEASE_TEMPLATE.md for the expected form."
        )
        return 1
    print("Release PR body form ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
