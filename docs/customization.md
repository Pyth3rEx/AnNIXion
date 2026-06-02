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

A VS Code module with full Nix language support is available:

- **Language server:** `nil` — code completion and diagnostics
- **Formatting:** Auto-format on save, 2-space indentation
- **Linting:** Real-time error detection with `statix` and `deadnix`

Enable it in `user/home.nix`:

```nix
imports = [ ../modules/vscode.nix ];
```

Then `rebuild` and open VS Code.

---

## Adding tools

System packages are declared in `modules/security-tools.nix`. Add any nixpkgs package to the `environment.systemPackages` list and rebuild.

For tools not in nixpkgs, add a derivation under `overlays/` (see [docs/roadmap.md](roadmap.md) Phase 9).
