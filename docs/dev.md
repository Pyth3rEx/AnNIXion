# Developer Guide

This document covers how to contribute to AnNIXion, run CI checks locally, and verify your work before opening a pull request.

> For the high-level branch model, commit conventions, and PR checklist, start with [CONTRIBUTING.md](../CONTRIBUTING.md). This guide is the detailed CI/tooling reference it points to.

---

## Contributor flow

```
feature-branch  →  dev  →  (maintainer)  →  main
```

- Open your PR against **`dev`**, not `main`.
- The maintainer merges `dev` → `main` and bumps `VERSION`.
- **Do not** touch `VERSION` or open PRs directly against `main`.

---

## Quick start

```bash
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cd ~/.dotfiles
nix develop
```

The dev shell provides `nixfmt`, `statix`, `deadnix`, `shellcheck`, `jq`, `sbomnix`, `nil`, and `nix-output-monitor`. It does not touch `hardware-configuration.nix` — build `AnNIXion-ci` instead, which pairs the full system with `system/hardware-stub.nix`.

If you are running AnNIXion, your real `hardware-configuration.nix` is already present and the `AnNIXion` configuration is offered alongside it.

---

## CI levels

| Level | Command | What it checks | Typical runtime |
|---|---|---|---|
| **L0** | `.github/scripts/lint.sh`, `tests/repo/milestone.sh` | Formatting, Nix anti-patterns, dead code, shell bugs, eval warnings, script fixtures | ~2 min |
| **L1** | `nix flake check --no-build` | Syntax, type errors, undefined references | ~5 s |
| **L2** | `nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel` | Full system closure — all packages resolve | 5–15 min |
| **L3** | `nix build .#checks.x86_64-linux.<test>` — CI builds every check the flake defines | VM boot + service behaviour + tool presence (needs KVM) | ~10 min |

Seven VM tests exist — `boot`, `security-tools`, `vpn-enforcement`, `shells`,
`xrdp-session`, `bind-axfr` and `git-credential-helper`. L1 evaluates all of
them; CI's L3 step discovers and builds every check the flake defines, so a
test that is wired in cannot fail to run. Run one on its own with
`nix build .#checks.x86_64-linux.vpn-enforcement`.

**Supply-chain artifacts**

The `check` job also builds the three files that ship with each release, because
it is the job that has already built the closure and separate jobs share no Nix
store. `iso` downloads them as an artifact and publishes them.

| Asset | What it is |
|---|---|
| `annixion-<v>.cdx.json` | CycloneDX SBOM of the **installed** closure. The operational artifact — point scanners here. |
| `annixion-<v>.buildtime.cdx.json` | The same, plus every build input: toolchains, fetched archives, patches. Provenance, not exposure. |
| `annixion-<v>.supply-chain.md` | Both of the above rendered as one readable page, in two halves that are never summed. |

Generate all three locally:

```bash
.github/scripts/generate-sbom.sh --out-dir /tmp/sbom
```

It scans `AnNIXion-ci` twice — once for runtime, once with `--buildtime` — so
budget a few minutes on a warm store. Pass a different target with
`SBOM_TARGET`; it must be a flakeref, since sbomnix given a bare store path
cannot reach nixmeta and quietly drops every licence.

Closure size and store-path count are measured at generation time, stamped into
both SBOMs as `annixion:closure_*` properties, and read back out by the release
job. **No figure for these is hardcoded anywhere** — a closure size quoted in
prose is wrong by the next release and nothing catches it.

The two halves stay apart on purpose. A CVE against a compiler that built the
image is not running on an operator's machine, and rolling it into the same
count as the installed closure produces a large frightening number that means
nothing. `render-supply-chain.sh` enforces the split; `tests/repo/supply-chain.sh`
checks that it holds.

**Security pages**

`cve-status.yml` runs weekly and on demand. It builds the closure, scans it with
`vulnxscan` against the flakeref — not the SBOM, since `vulnix` needs live store
paths and is the only engine that sees some findings — resolves licences and
maintainers from nixpkgs `meta`, and writes four files to `docs/security/`.

It commits only when the pages say something new. The scan stamps every page
with its own run time, so a plain `git diff` is never empty;
`security-pages-changed.sh` neutralises just the timestamp and compares the
rest. The committed history is meant to read as a CVE timeline, which it cannot
do if every week logs a clock update.

`ci.yml` carries `paths-ignore` for `docs/security/**`. Its `iso` job fires on
any push to `main` with no path filter, so without that guard each weekly commit
would start a three-hour ISO build to republish a tag that already exists.

Regenerate locally against a scan you already have:

```bash
.github/scripts/render-security-pages.py \
  --triage vulns.triage.csv --vulns vulns.csv \
  --provenance <(.github/scripts/package-provenance.sh --triage vulns.triage.csv) \
  --apps <(.github/scripts/installed-apps.sh) \
  --sbom annixion-<v>.cdx.json --out-dir docs/security --coverage reduced
```

Pass `--coverage reduced` for anything scanned from an SBOM rather than a live
closure; the page says so in its own caveats.

**CVEs a pull request introduces**

The weekly scan describes the release that already shipped, so a package added
by a pull request is invisible until the following Monday — by which point it is
in `main`. `cve-pr.yml` closes that gap by scanning only what the branch adds.

It builds both closures, lists them with `nix path-info -r`, and hands the
difference to `closure-added.py`. The second build is not a second closure's
worth of work: the two share everything the branch did not touch, and those
paths are already in the runner's store. Most of the difference is not a package
either — any configuration change rewrites `etc`, `system-path` and the system
derivation, and each of those references the whole closure, so letting one
through would scope the scan straight back to everything. A path has to have a
name and a version to be kept.

`scan-target.sh` then builds one store path out of the added set, because
`vulnxscan` takes a single target and the added set is not closed under
references. It uses `builtins.storePath`, not the paths as text: nix records a
reference only where the string carrying it has context, and a target built from
plain text has a closure of one file — it scans clean and reports nothing wrong.
`tests/repo/pr-cve-scan.sh` builds a real target and checks the references are there.

That target's closure covers the added packages' dependencies too, most of which
were already in the base. That is the price of keeping `vulnix`, which is
nix-only and refuses an SBOM; `render-pr-cve.py` filters the findings back down
to the added packages and reuses the grading and buckets of
`render-security-pages.py`, so the two never disagree about a severity.

`CVE_PR_THRESHOLD` (default `9.0`) is the CVSS at or above which the check goes
red; `CVE_PR_MODE=comment` keeps it green and lets the comment be the whole
signal. A finding repology says does not apply never gates. The comment is
posted by `cve-pr-comment.yml` on `workflow_run`, for the same reason
`pr-summary.yml` exists: the `pull_request` token is read-only on a fork and
cannot comment. It matches the pull request by head SHA against this
repository's open ones and never reads a number out of the artifact, which a
fork controls.

The trigger carries a `paths` filter — only a `.nix` file or the lock can move
the closure, and nothing else is worth two builds. A run skipped by a path
filter stays pending forever if it is made a required check, so leave it
advisory or require it through a merge queue.

**[testing.md](testing.md) covers the suite itself** — what each test is for,
which kind a change needs, and how to wire a new one in. Every feature ships
with its tests.

**Lint (L0)**

One script runs every linter, so local, editor and CI agree:

```bash
.github/scripts/lint.sh
```

It runs `nixfmt --check`, `statix`, `deadnix` and `shellcheck` over the tracked
files, plus a `nix flake check` pass for module evaluation warnings, keeps going after the first failure so one pass reports everything, and
prints each finding as a GitHub annotation — in CI those land on the pull
request diff. Run `nixfmt <file>` to apply formatting.

**Errors and warnings fail the run. Info-level findings are reported but do
not.** The tail of the output is a per-tool table of the three counts. On a
pull request CI lints the base revision as well and shows the movement in
brackets — `2 (+1)` means this branch added one — then posts the table as a
comment, replacing the previous one so it stays at the end of the discussion.

`LINT_SKIP_EVAL=1` skips the flake evaluation, which is the slow part.

Two details worth knowing if you run the tools by hand:

- **A tool that cannot run counts as an error.** `statix` reports a bad config
  on stderr and still exits 0, so an empty result is not taken as a clean one —
  stderr is checked as well as the exit code.
- **`deadnix` reports the `{ config, lib, pkgs, ... }` module signature as
  info.** That signature is convention rather than a defect, so it is visible
  without blocking. Any other dead code is a warning and blocks.
- **`nix-eval` runs `nix flake check` with the eval cache off.** NixOS module
  warnings are emitted only on a cold evaluation, so without that they appear
  once and never again. They are reported as info.
- **`statix.toml` disables `repeated_keys`.** That lint wants each `environment`
  or `services` block merged into one attribute set; the tree deliberately
  groups them under their own section headers instead.

**Script tests**

```bash
tests/repo/milestone.sh
```

Fixture tests for `.github/scripts/assign-milestone.sh` and
`.github/scripts/board-status.sh`, covering which milestone new work lands on,
which milestone is the release being built, and which column that puts a
triaged issue in. They drive the real scripts through their `--select`,
`--select-nearest` and `--decide` modes rather than reimplementing the choice,
so they cannot drift from it. No network, no GitHub, no Nix build — they run in
well under a second, and CI runs them in the same **Lint** job.

The VM tests under `tests/*.nix` are a different thing: those are nixosTests
built by L1 and L3.

L0 and L1 before every push. L2 before opening a PR. L3 is optional locally —
CI runs it on every PR. The ISO build and its size gate run only on PRs into
`main` and on pushes to `main`.

---

## Running a full CI run locally

The `github-local-actions` extension, installed with the editor in
`home/apps/vscodium.nix`, runs `.github/workflows/ci.yml` on this machine. It
needs Docker and [`act`](https://github.com/nektos/act). Reach for it when you
want a full CI run including the ISO build; for everything else the commands
below are faster.

---

## Running checks

The levels, as commands:

```bash
# L1 — fast, always run before pushing
nix flake check --no-build

# L0 — every linter, plus the script fixture tests
.github/scripts/lint.sh
tests/repo/milestone.sh

# L2 — recommended before opening a PR
nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel \
  --print-build-logs --no-link

# L3 — optional locally, runs in CI. Discovered the way CI discovers them,
# so this does not go stale as tests are added.
nix build $(nix eval --json '.#checks.x86_64-linux' --apply builtins.attrNames \
  | jq -r '.[] | ".#checks.x86_64-linux." + .') --print-build-logs --no-link
```

Use `nom` (nix-output-monitor) for a cleaner build display:

```bash
nix build .#... --print-build-logs --no-link 2>&1 | nom
```

---

## Pre-push checklist

Before pushing your branch or opening a PR:

- [ ] `nix flake check --no-build` passes
- [ ] `.github/scripts/lint.sh` clean (CI runs it as the **Lint** check)
- [ ] `tests/repo/milestone.sh` passes
- [ ] `nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel --no-link` succeeds (recommended)
- [ ] **The change ships with its tests** — see [testing.md](testing.md). If it
      genuinely needs none, say so in the PR.

---

## Project board automation

`.github/workflows/project.yml` keeps the [project board](https://github.com/users/Pyth3rEx/projects/3)
in step with issues and pull requests, so status is a consequence of the work
rather than something to remember:

| Event | Effect |
|---|---|
| Issue opened | Added to the board as **Backlog**, labelled `needs triage`, put on the furthest milestone. Priority and Size are read from the issue form. |
| `needs triage` removed | **Up next** if the issue sits on the nearest open milestone, otherwise **Ready** — only if the issue is still in Backlog, so triaging something already underway does not pull it back |
| Milestone set or cleared | **Up next** or **Ready**, by the same rule — only from those two columns, so scoping a release never drags back work already underway |
| Issue assigned | **In progress** |
| PR opened | **In progress**, put on the furthest milestone — **Ready** while it is a draft |
| PR marked ready for review, or sent back to draft | **In progress**, or **Ready** again |
| PR closed without merging | **Done**. Nothing else moves: an unmerged PR closes no issues |
| PR merged into `dev` | **In review**, along with every issue the PR closes |
| PR merged into `main` | **Done** — the PR, the issues it closes, and everything else still in review. Then the new release's Ready work is swept into **Up next**. |
| Milestone closed | The now-nearest milestone's Ready work is swept into **Up next** |

The `main` rule is what retires the work. A feature PR merging into `dev` does
not close its issues, because closing keywords only fire on the default branch;
the release PR into `main` does. Everything that reached `dev` is in review by
then, so the sweep moves the whole release to Done at once.

---

## Unanswered reviews

`.github/workflows/stale-reviews.yml` runs daily and closes pull requests that
were asked for changes and never answered. The clock starts at the most recent
*changes requested* review and is reset by anything the author does after it —
a push, a comment, a reply on the diff. A warning lands at 21 days and the close
at 30, so the close is never the first anyone hears of it, and closing is not a
rejection: reopening costs nothing.

Only the review matters, not general activity. A pull request being discussed by
other people does not keep an unanswered review alive, and a pull request nobody
has touched is left alone until a review actually asks for something.

Run it by hand from the Actions tab to see what it would do; the manual trigger
defaults to a dry run, which reports each verdict and touches nothing. Worth
doing after changing `WARN_DAYS` or `CLOSE_DAYS`, since this closes other
people's work. `tests/repo/stale-reviews.sh` drives the same decision through
`--decide`, so the thresholds are covered without a network.

### Ready and Up next

The two columns split triaged work by release, and the milestone is what
decides which one an issue is in:

| Column | Milestone |
|---|---|
| **Ready** | Any open milestone further out than the next release, or none at all |
| **Up next** | The **nearest** open milestone — the release being built |

New work is assigned the **furthest** milestone, so it lands in Ready and the
current release stays as scoped. Pulling something into the release is a single
act — set its milestone to the nearest one, and the board follows. Both scripts
read "nearest" the same way `assign-milestone.sh` reads "furthest": the lowest
version among the versioned milestones, falling back to the earliest due date
when none are versioned.

Closing a milestone is what makes the next one nearest, so that is when its
Ready work becomes Up next. Merging into `main` runs the same sweep, for the
case where the milestone is closed before the release PR merges — the sweep is
idempotent, so running it twice costs nothing.

Priority and Size come from dropdowns in the issue forms and are written **only
when empty**, so a maintainer's correction on the board is never overwritten by
a re-run.

### Required secret

Project boards are not repository objects, and the built-in `GITHUB_TOKEN`
cannot write to them. The workflow reads `secrets.PROJECT_PAT`.

It has to be a **classic** token with the `project` scope. Fine-grained tokens
carry no Projects permission for a personal account — that permission exists
only for organization-owned projects — so a fine-grained token authenticates and
then fails every board mutation. Moving the board to an organization is the only
way to use a fine-grained token here.

`project` is the sole scope required. Everything that touches the repository —
labels, milestones, resolving the issues a PR closes — runs under `GITHUB_TOKEN`
instead, so the classic token's reach stops at the board.

Without that secret the board jobs fail; nothing else in CI is affected.

### Changing the board

`.github/scripts/project-sync.sh` resolves field and option IDs **by name** at
run time, so renaming the project or rebuilding it does not silently break the
automation — a missing name fails loudly instead. Adding a status means adding
its name to the workflow, not chasing IDs.

The **Up next** option has to exist on the board's Status field, spelled exactly
that way, before the workflow can use it. Add it between Ready and In progress;
every board job fails loudly until it is there.

```bash
export GH_TOKEN=<token with project scope>
.github/scripts/project-sync.sh sync --content <issue-node-id> --status Ready
.github/scripts/project-sync.sh sync --content <issue-node-id> \
  --status "Up next" --only-if-status "Ready,Up next"
.github/scripts/project-sync.sh sweep --from "In review" --to Done
.github/scripts/project-sync.sh sweep --from Ready --to "Up next" \
  --milestone "0.4.0 - Nebula"
```

`--only-if-status` takes a comma-separated list, and `sweep --milestone`
restricts a sweep to one release.

---

## Hardware configuration

`hardware-configuration.nix` is machine-specific and gitignored. The disk layout
is the only thing that varies between a real install and CI, so the flake ships
two configurations built from the same modules:

| Configuration | Disk layout | Offered when |
|---|---|---|
| `AnNIXion` | `./hardware-configuration.nix` | that file exists |
| `AnNIXion-ci` | `./system/hardware-stub.nix` | always |

Nothing ever copies the stub to `hardware-configuration.nix`. A placeholder at
that path is indistinguishable from a real machine's config, and rebuilding from
one produces a system whose root device does not exist.

- **Running on AnNIXion** — your real file is already at the repo root. Build
  `AnNIXion`.
- **Contributing from another machine** — build `AnNIXion-ci`. `nix flake check`
  passes with no hardware configuration present.

If `nixos-rebuild --flake .#AnNIXion` reports that the flake does not provide
that attribute, your `hardware-configuration.nix` is missing or unstaged:

```bash
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
git add -f hardware-configuration.nix   # flakes only read tracked or staged files
```

Do not commit `hardware-configuration.nix`.
