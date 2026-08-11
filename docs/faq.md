# FAQ

Common setup and troubleshooting questions. See also
[Installation](installation.md), [Usage](usage.md), and
[Customization](customization.md).

---

## Install & boot

### The installer fails with `Can't lookup blockdev`

This was a race between `mkfs` and udev populating `/dev/disk/by-label/*`. It is
fixed in current `annixion-install`, which mounts partitions by device node and
runs `udevadm settle` after formatting. Rebuild/redownload the ISO from the
latest release.

### The install fails saying `hardware-configuration.nix` is missing

Nix flakes only evaluate files tracked by git, and the generated
`hardware-configuration.nix` is gitignored. The installer force-stages it into
the git index before running `nixos-install`. If you are installing manually on
existing NixOS, remember the `-f`:

```bash
git -C ~/.dotfiles add hardware-configuration.nix -f
```

### Where does the installer put the config?

At `~/.dotfiles` (i.e. `/home/operator/.dotfiles`) — **not** `/etc/nixos`. The
Home Manager config references runtime paths under `~/.dotfiles` (wallpaper,
Firefox icons, certs) and the shell aliases target it, so that is its canonical
location.

### My wallpaper (or Firefox icons) didn't apply

Those assets are referenced from `~/.dotfiles/assets/…` at runtime. If the
config isn't at `~/.dotfiles`, or the directory isn't owned by `operator`, the
paths dangle and Plasma silently skips them. A fresh install from the current
ISO clones to `~/.dotfiles` and `chown`s it to `operator` automatically.

---

## Day-to-day

### How do I apply a change?

```bash
rebuild    # sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure
```

`upgrade` updates all flake inputs then rebuilds; `update` refreshes inputs
without rebuilding. Full alias list: [zsh.md](zsh.md).

### Why does `rebuild` use `--impure`?

The flake reads the machine-local `hardware-configuration.nix`, which lives
outside the pure evaluation guarantees Nix normally enforces. `--impure` allows
that read. It is expected and safe here.

### How do I add a security tool?

Add the nixpkgs package to `environment.systemPackages` in
`modules/security-tools.nix` and run `rebuild`. See
[customization.md](customization.md).

### How do I change a setting without touching shared config?

Use the `user/` override system — `user/configuration.nix` (system) and
`user/home.nix` (user environment). Base options use `lib.mkDefault`, so your
values win without `lib.mkForce` (the one exception is Firefox proxy prefs; see
[usage.md](usage.md)). Details in [user/README.md](../user/README.md).

### I created a new file in `user/` and Nix doesn't see it

Flakes only see git-tracked files. Run `git add` on the new file before
`rebuild`. Editing an existing tracked file needs no `git add`.

---

## Browsers & proxies

### A browser profile won't connect to anything

That's by design. The Red Team profile fails closed unless Burp is running on
`127.0.0.1:8080`; OSINT and Puppet Master fail closed unless a SOCKS5 proxy is
on `127.0.0.1:1080`. Start the proxy, or override enforcement per
[usage.md](usage.md#bypassing-proxy-enforcement-via-user-overrides).

### Firefox shows certificate warnings through Burp

Run `burp-ca` while Burp is running, then `rebuild`. This fetches Burp's CA and
trusts it via Firefox enterprise policy. Re-run only if Burp regenerates its CA.

### My VPN uses a different SOCKS port

Override `network.proxy.socks_port` for the `osint` and `puppet` profiles from
`user/` — see [usage.md](usage.md#osint--puppet-master--vpn-setup).

---

## CI & contributing

### CI rejects my PR for committing `hardware-configuration.nix`

It's machine-specific and gitignored. Remove it from your commit; CI and the dev
shell generate a stub from `ci/hardware-stub.nix` automatically. See
[dev.md](dev.md) and [CONTRIBUTING.md](../CONTRIBUTING.md).

### CI fails on a version bump

Only the `dev` → `main` merge needs a `VERSION` bump, and the maintainer owns
it. Don't bump `VERSION` in feature PRs against `dev`.

### The ISO build fails the size gate

The release ISO must stay under the GitHub asset limit (the CI gate rejects
oversized images). Trim added packages or move heavy tooling behind an optional
module rather than the base ISO.
