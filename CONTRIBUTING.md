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

Run at least L1 + lint locally (see [docs/dev.md](docs/dev.md) for all levels):

```bash
nix flake check --no-build     # L1 — syntax / type / references
statix check .                 # anti-pattern linter
deadnix .                      # unused bindings
nixfmt --check .               # formatting (run `nixfmt .` to fix)
```

Building the full system closure (L2) before opening a PR is recommended:

```bash
nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel --no-link
```

CI runs L1–L3, the ISO build, and the size gate on every PR to `dev`.

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

Use the issue templates under **Issues → New issue**. For anything security
sensitive, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.
