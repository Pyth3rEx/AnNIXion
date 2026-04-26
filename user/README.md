# AnNIXion — User Override System

This folder is yours. Edit the files here to personalise AnNIXion without
touching the base configuration. You will never need `lib.mkForce`.

---

## How it works

Every option in the base config is marked `lib.mkDefault`. That means the
distro is saying *"use this unless the user says otherwise."*

Your files here have higher priority by default (100 vs 1000). So:

```nix
# base config says:
time.timeZone = lib.mkDefault "Europe/Paris";

# you write in user/configuration.nix:
time.timeZone = "America/New_York";   # ← this wins, no lib.mkForce needed
```

---

## Files in this folder

```
user/
├── configuration.nix     system-level overrides (hostname, timezone, packages…)
├── home.nix              user-environment overrides (shell, git, apps…)
└── examples/
    ├── git.nix           ready-to-use git identity override
    └── zsh.nix           welcome banner + recon aliases
```

---

## Getting started

**Step 1 — set your git identity**

Open `user/home.nix` and uncomment the git example:

```nix
imports = [
  ./examples/git.nix
];
```

Then open `user/examples/git.nix` and fill in your name and email.

**Step 2 — add the welcome banner (optional)**

Also uncomment in `user/home.nix`:

```nix
imports = [
  ./examples/git.nix
  ./examples/zsh.nix
];
```

**Step 3 — apply**

```bash
sudo nixos-rebuild switch --flake .#AnNIXion
```

---

## Common overrides

### `user/configuration.nix` — system settings

```nix
# Hostname
networking.hostName = "my-machine";

# Timezone
time.timeZone = "America/Chicago";

# Extra system-wide package
environment.systemPackages = with pkgs; [ docker ];

# Add yourself to a group
users.users.operator.extraGroups = [ "wheel" "networkmanager" "docker" ];
```

Full option list: <https://nixos.org/manual/nixos/stable/options>

### `user/home.nix` — your personal environment

```nix
# Extra user packages
home.packages = with pkgs; [ obsidian signal-desktop ];

# Override a shell alias
programs.zsh.shellAliases.rebuild =
  "sudo nixos-rebuild switch --flake /my/path#AnNIXion";

# Change xterm font size
xresources.properties."XTerm.faceSize" = 13;
```

Full option list: <https://nix-community.github.io/home-manager/options.xhtml>

---

## Git note

If you create a **new file** in this folder, run `git add` before rebuilding —
NixOS flakes only see files that are tracked by git. Editing an existing file
(like this one) needs no `git add`.

---

## Things to leave alone

| File / option | Why |
|---|---|
| `hardware-configuration.nix` | Generated for your specific machine |
| `home.stateVersion` in `home.nix` | Records your Home Manager install version |
| `system.stateVersion` in `flake.nix` | Records your NixOS install version |
| `lib.mkForce` in `modules/xrdp.nix` | Required for Hyper-V Enhanced Session to work |