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

The dev shell provides `nixfmt`, `statix`, `deadnix`, `nil`, and `nix-output-monitor`. It does not touch `hardware-configuration.nix` — build `AnNIXion-ci` instead, which pairs the full system with `ci/hardware-stub.nix`.

If you are running AnNIXion, your real `hardware-configuration.nix` is already present and the `AnNIXion` configuration is offered alongside it.

---

## CI levels

| Level | Command | What it checks | Typical runtime |
|---|---|---|---|
| **L1** | `nix flake check --no-build` | Syntax, type errors, undefined references | ~5 s |
| **L2** | `nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel` | Full system closure — all packages resolve | 5–15 min |
| **L3** | `nix build .#checks.x86_64-linux.{boot,security-tools}` | VM boot + tool presence (needs KVM) | ~10 min |

Three VM tests exist — `boot`, `security-tools` and `vpn-enforcement`. L1
evaluates all three; CI's L3 step builds the first two. Run the killswitch
regression suite locally with
`nix build .#checks.x86_64-linux.vpn-enforcement`.

**Lint**

```bash
statix check .    # Nix anti-pattern linter
deadnix .         # Find unused bindings
nixfmt --check .  # Format check
nixfmt .          # Auto-format (apply)
```

Run L1 + lint before every push. L2 before opening a PR. L3 is optional locally
— CI runs it on every PR. The ISO build and its size gate run only on PRs into
`main` and on pushes to `main`.

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
- [ ] `statix check .` clean
- [ ] `deadnix .` clean
- [ ] `nixfmt --check .` passes (or run `nixfmt .` to fix)
- [ ] `nix build .#nixosConfigurations.AnNIXion-ci.config.system.build.toplevel --no-link` succeeds (recommended)

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
