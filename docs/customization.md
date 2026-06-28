# Customization

## User override system

All base config options use `lib.mkDefault`, so settings in `user/` win automatically — no `lib.mkForce` needed (except for Firefox proxy prefs, see [usage.md](usage.md)).

The `user/` directory is never committed upstream. It survives reinstalls when you clone your own fork.

### Getting started

**Set your git identity** — uncomment the example in `user/home.nix`:

```nix
imports = [ ./examples/git.nix ];
```

Then fill in `user/examples/git.nix` with your details.

**Add a welcome banner** — uncomment the ZSH example:

```nix
imports = [ ./examples/zsh.nix ];
```

Apply any change with:

```bash
rebuild
```

See `user/README.md` for the full override system documentation.

---

## Development environment

VSCodium ships as part of the base user environment (`home/vscodium.nix`) with full Nix language support out of the box:

- **Language server:** `nil` — code completion and diagnostics
- **Formatting:** `nixfmt` — auto-format on save, 2-space indentation
- **Linting:** Real-time error detection with `statix` and `deadnix`
- **direnv:** Automatic environment loading via `nix-direnv`

No manual activation needed — it is included by default. Open VSCodium after the first `rebuild`.

---

## Adding tools

System packages are declared in `modules/security-tools.nix`. Add any nixpkgs package to the `environment.systemPackages` list and rebuild.

For tools not in nixpkgs, add a derivation under `overlays/` (see [docs/roadmap.md](roadmap.md) Phase 9).

---

## Versioning

Every PR to `main` must bump the `VERSION` file. CI enforces this and fails the build if the version has not changed.

Follow semantic versioning:

| Change type | Example |
|---|---|
| Bug fix / small tweak | `0.1.0` → `0.1.1` |
| New feature | `0.1.1` → `0.2.0` |
| Breaking change | `0.2.0` → `1.0.0` |

The ISO filename and GitHub release tag are derived from this file automatically.
