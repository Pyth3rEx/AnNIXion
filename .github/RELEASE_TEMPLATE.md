<!--
  RELEASE PR TEMPLATE — dev → main
  =================================
  Copy this into the description of the `dev → main` pull request when cutting a
  release. On merge, CI publishes a GitHub Release tagged `v<VERSION>` and uses
  THIS text as the release notes, then appends an auto-generated "All changes in
  this release" PR list below it.

  Guidelines:
  - Write for end users and operators, not reviewers.
  - Keep entries in the imperative/plain voice, one change per bullet.
  - Omit empty sections. Link issues/PRs with #<number>.
  - Bump VERSION in the same PR (minor for features, patch for fixes, major for
    breaking changes) — CI rejects the merge if VERSION is unchanged.
-->

Short one-paragraph summary of what this release delivers and who it's for.

## Highlights

- Lead with the 2–4 changes that matter most, phrased as outcomes.

## Added

- New features, tools, modules, or docs.

## Changed

- Behavior, defaults, structure, or dependencies that changed.

## Fixed

- Bugs resolved. Reference the issue: `Fixes #<n>`.

## Upgrade notes

- Anything an existing user must do by hand (manual steps, breaking changes,
  data migrations). Write "None." if there are none.

---

**Version:** `<OLD>` → `<NEW>`
