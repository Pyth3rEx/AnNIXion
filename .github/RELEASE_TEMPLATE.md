<!--
  RELEASE PR TEMPLATE — dev → main
  =================================
  Copy this into the description of the `dev → main` pull request when cutting a
  release. On merge, CI publishes a GitHub Release tagged `v<VERSION>` and uses
  THIS text as the release notes, then appends an auto-generated "All changes in
  this release" PR list below it.

  The form below is enforced by the `Release PR form` check
  (.github/scripts/check-release-form.py). Validate a draft before opening the PR:

      python3 .github/scripts/check-release-form.py my-draft.md

  Rules:
  - Sections are `## Added`, `## Changed`, `## Removed`, `## Fixed` — spelled
    exactly, at least one present. Omit the ones you do not need.
  - Every bullet in those sections starts with its own section name and a colon:
    `- Added: …`, `- Fixed: …`. One change per bullet, on one line, no sub-bullets.
  - `## Upgrade notes` is mandatory. Write "None." if there is nothing to do.
  - Every `#<n>` you mention must either carry a closing keyword, sit under
    `## Known issues, not closed here`, or be written as a full URL (merged PRs).
    A bare `(#12)` does NOT close anything — that is the whole point of the check.
  - Write for end users and operators, not reviewers.
  - Bump VERSION in the same PR (minor for features, patch for fixes, major for
    breaking changes) — CI rejects the merge if VERSION is unchanged.
  - Name the release in RELEASE_NAME: one line, under 24 characters, its own
    name every time. It becomes the release title — "AnNIXion 0.3.0 —
    Killswitch" — so make it short and punchy. CI rejects a reused name.
-->

Short one-paragraph summary of what this release delivers and who it's for.

## Highlights

- Lead with the 2–4 changes that matter most, phrased as outcomes.

## Added

- Added: new features, tools, modules, or docs — one per line.

## Changed

- Changed: behavior, defaults, structure, or dependencies that changed.

## Removed

- Removed: what no longer ships, and the one line that restores it.

## Fixed

- Fixed: the bug, in terms of what the user saw going wrong.

## Upgrade notes

- Anything an existing user must do by hand (manual steps, breaking changes,
  data migrations). Write "None." if there are none.

## Issues closed on merge

- Closes #<n> — one line on why this release resolves it.

## Known issues, not closed here

- #<n> — referenced but still open, and why it stays open.

---

**Version:** `<OLD>` → `<NEW>`
