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
time.timeZone = lib.mkDefault "UTC";

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
    ├── zsh.nix           welcome banner + recon aliases
    └── hackthebox.nix    HTB networking helper (dnsmasq, annixion-htb-hosts, annixion-htb-vpn)
```

---

## This folder holds secrets once it holds a password

`annixion-install`'s wizard (or you, by hand) sets
`users.users.operator.hashedPassword` and `annixion.sysreptor.hashedPassword`
here. They're hashes, not plaintext, but treat the folder as secret-bearing
from that point on — don't paste its contents anywhere public, and don't
commit it to a fork you intend to share.

---

## Nixpkgs cooldown

If the wizard's nixpkgs cooldown question picked anything other than
"same as the repo," that policy is stamped in `user/.annixion-nixpkgs-pin`
— not a secret, just a policy. The `update`/`upgrade` aliases reapply it
automatically after `nix flake update`, since a plain flake update has no
memory of the override on its own; run `annixion-nixpkgs-cooldown` by hand
if you ever call `nix flake update` some other way.

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
rebuild    # alias for: sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure
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
environment.systemPackages = with pkgs; [ tcpdump ];

# Add yourself to a group
users.users.operator.extraGroups = [ "wheel" "networkmanager" "docker" ];

# Drop a Firefox profile you don't want (all four ship by default)
annixion.firefox.profiles.puppet.enable = false;
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
| `home.stateVersion` in `home/` | Records your Home Manager install version |
| `system.stateVersion` in `flake.nix` | Records your NixOS install version |
| `lib.mkForce` in `system/xrdp.nix` | Required for Hyper-V Enhanced Session to work |