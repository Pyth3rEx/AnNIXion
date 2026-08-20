# Contributing to AnNIXion

Thanks for wanting to improve AnNIXion. This guide covers the branch model,
how to set up a working environment, and what to check before opening a pull
request. For the detailed local-CI reference (levels, VSCodium tasks, terminal
commands) see [docs/dev.md](docs/dev.md).

---

## Branch model

```
feature-branch  →  dev  →  (maintainer)  →  main
```

- **Open every PR against `dev`, never `main`.**
- The maintainer merges `dev` → `main` and owns the release.
- **Do not** bump the `VERSION` file yourself and **do not** open PRs directly
  against `main`. CI enforces a version bump only on the `dev` → `main` merge.
- Each release also carries a codename in `RELEASE_NAME` — one line, under 24
  characters, never reused. It forms the release title (`AnNIXion 0.3.0 —
  Killswitch`), so keep it short and punchy. The maintainer sets it with the
  version bump; CI rejects the release PR if it is missing, empty or unchanged.

---

## Setup

```bash
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cd ~/.dotfiles
nix develop        # provides nixfmt, statix, deadnix, nil, nix-output-monitor
```

You do not need a `hardware-configuration.nix` to work on AnNIXion. The
`AnNIXion-ci` configuration pairs the full system with `ci/hardware-stub.nix`,
so the flake evaluates and builds on any machine. `AnNIXion` itself is only
offered once you have a real `hardware-configuration.nix` in the repo root.

Never commit `hardware-configuration.nix` — it is machine specific and
gitignored, and CI rejects PRs that add it.

---

## Before you push

Run at least L0 + L1 locally (see [docs/dev.md](docs/dev.md) for all levels):

```bash
.github/scripts/lint.sh        # L0 — nixfmt, statix, deadnix, shellcheck
nix flake check --no-build     # L1 — syntax / type / references
```

L0 is the same script CI runs as the **Lint** check, so a clean run locally
means a clean run there. Run `nixfmt <file>` to apply formatting.

Building the full system closure (L2) before opening a PR is recommended:

```bash
nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel --no-link
```

CI runs L0–L3 on every PR, whatever the target branch. The ISO build, the size
gate and the version/release-name gates only run on PRs into `main` and on
pushes to `main`.

---

## Commit and PR conventions

- Use [Conventional Commits](https://www.conventionalcommits.org/): `fix(installer): …`,
  `feat(firefox): …`, `docs: …`, `chore(ci): …`.
- Keep each commit focused on one logical change — small, reviewable diffs.
- Write PR descriptions that state the **problem**, the **fix**, and how you
  **tested** it.
- Link the issue with a **closing keyword** — `Closes #12`, `Fixes #12`. A bare
  `(#12)` reads like a link but closes nothing on merge.
- Do not add `Co-Authored-By` trailers.

### Release PRs (`dev` → `main`)

The merged body is published verbatim as the GitHub Release notes, so its form
is checked by CI (`Release PR form`). Start from
[.github/RELEASE_TEMPLATE.md](.github/RELEASE_TEMPLATE.md):

- Sections are `## Added`, `## Changed`, `## Removed`, `## Fixed` — at least one,
  spelled exactly, and every bullet starts with its section name: `- Fixed: …`.
- One change per bullet, on one line, no sub-bullets.
- `## Upgrade notes` is mandatory — "None." is a valid answer.
- Every `#<n>` must carry a closing keyword, sit under
  `## Known issues, not closed here`, or be written as a full URL.
- The body ends with the version footer: ``**Version:** `OLD` → `NEW` ``.

Check a draft before opening the PR:

```bash
python3 .github/scripts/check-release-form.py my-draft.md
```

---

## Adding tools

System-wide security tools live in `modules/security-tools.nix`. Add the
nixpkgs package to `environment.systemPackages` with a short inline comment,
then rebuild and confirm it resolves. For tools not yet in nixpkgs, see the
overlays plan in [docs/roadmap.md](docs/roadmap.md) (Phase 9).

## Adding or changing user-facing config

Per-user environment lives under `home/` (shell, Firefox profiles, Plasma,
editors). Keep base options on `lib.mkDefault` so the `user/` override system
keeps working without `lib.mkForce`. See
[docs/customization.md](docs/customization.md).

---

## Reporting bugs and requesting features

Use the issue templates under **Issues → New issue**. Blank issues are turned
off, so pick the one that fits:

| Template | Use it for |
|---|---|
| **Bug Report** | Something is broken — config errors, tools crashing, build failures |
| **Feature Request** | A new capability, workflow, or system-level improvement |
| **Tool Request** | Packaging a new security tool. Tool additions have their own form; do not use Feature Request |
| **Documentation** | Something undocumented, wrong, or unclear |

For anything security sensitive, follow [SECURITY.md](SECURITY.md) and use
GitHub's private advisory flow instead of opening a public issue. The issue
chooser links straight to it.

Fill in the **Priority** and **Size** dropdowns honestly — they are read
straight off the form and written to the project board, so a filled-in form
saves a round trip. They are your estimate from where you sit; the maintainer
may adjust them.

---

## Issue triage

Every issue moves through the [project board](https://github.com/users/Pyth3rEx/projects/3),
and most of the movement is automatic. You do not need to update anything by
hand — opening the issue, getting assigned, and opening a pull request are what
drive it.

### What happens when you open an issue

Immediately, without anyone touching it:

- It is labelled **`needs triage`** and lands on the board in **Backlog**.
- It is put on the upcoming milestone.
- **Priority** and **Size** are read from the form and written to the board —
  but **only when those fields are empty**, so a maintainer's correction is
  never overwritten by a later re-run.

### What triage actually is

The maintainer reads the issue, adjusts Priority and Size if your estimate was
off, and **removes the `needs triage` label**. That removal is the triage
decision, and it moves the issue to **Ready**.

Removing the label is guarded: it only promotes an issue that is still in
Backlog. Triaging something already being worked on will not drag it backwards.

An issue that is rejected is closed with `wontfix`, `duplicate` or `invalid`
rather than being left to rot in Backlog.

### The statuses

| Status | Means | Set by |
|---|---|---|
| **Backlog** | Filed, not yet triaged | Opening the issue |
| **Ready** | Triaged, agreed, nobody has started | Removing `needs triage` |
| **In progress** | Someone is on it | Assigning the issue, or opening a PR |
| **In review** | Merged into `dev`, awaiting release | Merging a PR into `dev` |
| **Done** | Shipped in a release | Merging the release PR into `main` |

### Picking something up

Anything in **Ready** is fair game, and `good first issue` marks the gentler
ones. Say so on the issue and get it assigned to you — assignment is what moves
it to **In progress**, so it is also how everyone else knows not to duplicate
your work.

### Why your issue stays open after your PR merges

Link the issue from your pull request with a closing keyword — `Closes #12`,
not a bare `(#12)`, which reads like a link but closes nothing.

Even so, **merging into `dev` will not close it.** GitHub only acts on closing
keywords when a pull request merges into the default branch, which is `main`.
So a feature PR moves its issues to **In review**, and the `dev → main` release
PR is what actually closes them and sweeps everything still in review to
**Done**. An issue sitting open in **In review** after your work merged is the
system working, not a missed link.

### Labels

`bug`, `enhancement`, `documentation` and `tool request` are applied by the
templates. The rest are triage decisions: `good first issue`, `help wanted`,
`question`, `duplicate`, `invalid`, `wontfix`, and `needs triage` itself.

The exact workflow rules, the scripts behind them, and the token the board
automation needs are documented in
[docs/dev.md](docs/dev.md#project-board-automation).
