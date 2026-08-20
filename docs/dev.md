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

The dev shell provides `nixfmt`, `statix`, `deadnix`, `shellcheck`, `jq`, `nil`, and `nix-output-monitor`. It does not touch `hardware-configuration.nix` — build `AnNIXion-ci` instead, which pairs the full system with `ci/hardware-stub.nix`.

If you are running AnNIXion, your real `hardware-configuration.nix` is already present and the `AnNIXion` configuration is offered alongside it.

---

## CI levels

| Level | Command | What it checks | Typical runtime |
|---|---|---|---|
| **L0** | `.github/scripts/lint.sh`, `tests/milestone.sh` | Formatting, Nix anti-patterns, dead code, shell bugs, eval warnings, script fixtures | ~2 min |
| **L1** | `nix flake check --no-build` | Syntax, type errors, undefined references | ~5 s |
| **L2** | `nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel` | Full system closure — all packages resolve | 5–15 min |
| **L3** | `nix build .#checks.x86_64-linux.{boot,security-tools}` | VM boot + tool presence (needs KVM) | ~10 min |

Three VM tests exist — `boot`, `security-tools` and `vpn-enforcement`. L1
evaluates all three; CI's L3 step builds the first two. Run the killswitch
regression suite locally with
`nix build .#checks.x86_64-linux.vpn-enforcement`.

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
not.** The tail of the output is a per-tool table of the three counts; on a
pull request the same table is posted as a single comment that updates in
place, so the state of a branch is visible without opening the log.

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
tests/milestone.sh
```

Fixture tests for `.github/scripts/assign-milestone.sh`, covering which
milestone new work lands on. They drive the real script through its `--select`
mode rather than reimplementing the selection, so they cannot drift from it.
No network, no GitHub, no Nix build — they run in well under a second, and CI
runs them in the same **Lint** job.

The VM tests under `tests/*.nix` are a different thing: those are nixosTests
built by L1 and L3.

L0 and L1 before every push. L2 before opening a PR. L3 is optional locally —
CI runs it on every PR. The ISO build and its size gate run only on PRs into
`main` and on pushes to `main`.

---

## Running checks in VSCodium

Open `~/.dotfiles` as the workspace root in VSCodium. The repo ships a `.vscode/tasks.json` that wires up all CI commands.

| Shortcut / action | What runs |
|---|---|
| `Ctrl+Shift+B` | **Full check** — L0 lint + script tests + L1 in parallel |
| `Tasks: Run Task` → `CI: L2 — System Build` | Full system closure |
| `Tasks: Run Task` → `CI: L3 — VM Tests` | VM tests (requires KVM) |
| `Tasks: Run Task` → `Format: apply` | Auto-format all Nix files |

Each task opens in its own dedicated terminal panel so outputs don't interleave.

### GitHub Local Actions extension

The `github-local-actions` extension (already installed via `home/vscodium.nix`) lets you run the full `.github/workflows/ci.yml` locally. It requires Docker and [`act`](https://github.com/nektos/act). Use it when you want to reproduce a full CI run including the ISO build step.

---

## Running checks in the terminal

Same commands, without VSCodium:

```bash
# L1 — fast, always run before pushing
nix flake check --no-build

# L0 — every linter, plus the script fixture tests
.github/scripts/lint.sh
tests/milestone.sh

# L2 — recommended before opening a PR
nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel \
  --print-build-logs --no-link

# L3 — optional locally, runs in CI
nix build \
  .#checks.x86_64-linux.boot \
  .#checks.x86_64-linux.security-tools \
  .#checks.x86_64-linux.vpn-enforcement \
  --print-build-logs --no-link
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
- [ ] `tests/milestone.sh` passes
- [ ] `nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel --no-link` succeeds (recommended)

---

## Project board automation

`.github/workflows/project.yml` keeps the [project board](https://github.com/users/Pyth3rEx/projects/3)
in step with issues and pull requests, so status is a consequence of the work
rather than something to remember:

| Event | Effect |
|---|---|
| Issue opened | Added to the board as **Backlog**, labelled `needs triage`, put on the furthest milestone. Priority and Size are read from the issue form. |
| `needs triage` removed | **Ready** — only if the issue is still in Backlog, so triaging something already underway does not pull it back |
| Issue assigned | **In progress** |
| PR opened | **In progress**, put on the furthest milestone |
| PR merged into `dev` | **In review**, along with every issue the PR closes |
| PR merged into `main` | **Done** — the PR, the issues it closes, and everything else still in review |

That last rule is what retires the work. A feature PR merging into `dev` does
not close its issues, because closing keywords only fire on the default branch;
the release PR into `main` does. Everything that reached `dev` is in review by
then, so the sweep moves the whole release to Done at once.

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

```bash
export GH_TOKEN=<token with project scope>
.github/scripts/project-sync.sh sync --content <issue-node-id> --status Ready
.github/scripts/project-sync.sh sweep --from "In review" --to Done
```

---

## Hardware configuration

`hardware-configuration.nix` is machine-specific and gitignored. The disk layout
is the only thing that varies between a real install and CI, so the flake ships
two configurations built from the same modules:

| Configuration | Disk layout | Offered when |
|---|---|---|
| `AnNIXion` | `./hardware-configuration.nix` | that file exists |
| `AnNIXion-ci` | `./ci/hardware-stub.nix` | always |

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
