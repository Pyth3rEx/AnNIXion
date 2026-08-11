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

The dev shell provides `nixfmt`, `statix`, `deadnix`, `nil`, and `nix-output-monitor`. If `hardware-configuration.nix` is absent (e.g. on a contributor's machine that isn't running AnNIXion), the shell hook stubs it automatically from `ci/hardware-stub.nix`.

If you are running AnNIXion, your real `hardware-configuration.nix` is already present — no stub needed.

---

## CI levels

| Level | Command | What it checks | Typical runtime |
|---|---|---|---|
| **L1** | `nix flake check --no-build` | Syntax, type errors, undefined references | ~5 s |
| **L2** | `nix build .#nixosConfigurations.AnNIXion.config.system.build.toplevel` | Full system closure — all packages resolve | 5–15 min |
| **L3** | `nix build .#checks.x86_64-linux.{boot,security-tools}` | VM boot + tool presence (needs KVM) | ~10 min |

**Lint**

```bash
statix check .    # Nix anti-pattern linter
deadnix .         # Find unused bindings
nixfmt --check .  # Format check
nixfmt .          # Auto-format (apply)
```

Run L1 + lint before every push. L2 before opening a PR. L3 is optional locally — CI runs it on every PR.

---

## Running checks in VSCodium

Open `~/.dotfiles` as the workspace root in VSCodium. The repo ships a `.vscode/tasks.json` that wires up all CI commands.

| Shortcut / action | What runs |
|---|---|
| `Ctrl+Shift+B` | **Full check** — L1 + statix + deadnix in parallel |
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

# Lint
statix check .
deadnix .
nixfmt --check .

# L2 — recommended before opening a PR
nix build .#nixosConfigurations.AnNIXion.config.system.build.toplevel \
  --print-build-logs --no-link

# L3 — optional locally, always runs in CI
nix build \
  .#checks.x86_64-linux.boot \
  .#checks.x86_64-linux.security-tools \
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
- [ ] `statix check .` clean
- [ ] `deadnix .` clean
- [ ] `nixfmt --check .` passes (or run `nixfmt .` to fix)
- [ ] `nix build .#nixosConfigurations.AnNIXion.config.system.build.toplevel --no-link` succeeds (recommended)

---

## Hardware configuration

`hardware-configuration.nix` is machine-specific and gitignored. CI generates a minimal QEMU stub on every run (sourced from `ci/hardware-stub.nix`).

- **Running on AnNIXion** — your real file is already at the repo root. Nothing to do.
- **Contributing from another machine** — `nix develop` stubs it automatically. If you run nix commands outside the dev shell, copy the stub manually:

```bash
cp ci/hardware-stub.nix hardware-configuration.nix
```

Do not commit `hardware-configuration.nix`.
