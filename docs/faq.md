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

## Hyper-V Enhanced Session

### I have no audio in the guest

Two things have to be true, and the second one is easy to miss.

The guest side is handled by `modules/xrdp.nix`: Hyper-V emulates no sound
card, so audio only travels over xrdp's redirection channel, which the module
enables. See [Installation](installation.md#audio) for why that requires
PulseAudio rather than PipeWire.

The host side is not automatic. The Enhanced Session connection must be allowed
to play the guest's audio on the host — in Hyper-V Manager, connect to the VM,
choose **Show Options → Local Resources**, and direct audio playback to the
local computer. Without it there is no channel to redirect into and the guest
shows no audio device, however the guest is configured. The exact wording moves
around between Windows versions.

The setting is per connection, so check it again after connecting from a
different machine or Windows profile. A console login has no redirection
channel at all and will never have audio.

### Reconnecting hangs, or vmconnect says to contact the admin

Fixed in `modules/xrdp.nix` — rebuild and the next login is clean. Generations
before the fix set the operator account to linger, so `systemd --user` outlived
the session it belonged to. It kept `graphical-session.target` active pointing
at a `DISPLAY` that had gone away with the old X server, and the next login
asked systemd for a Plasma session it already believed was running: Enhanced
Session drops the connection, and a console login sits on the loading screen.

To recover a machine still running an affected generation, log in on the
console and clear the stale manager:

```sh
loginctl disable-linger operator
loginctl terminate-user operator
```

Rebooting works too. Rebuilding clears the linger flag for good.

If a reconnect fails after the fix, xrdp now logs to the journal — nixpkgs
sends its log to `/dev/null` by default, so before this there was nothing to
read:

```sh
journalctl -u xrdp -u xrdp-sesman -b
```

---

## Browsers & proxies

### A browser profile won't connect to anything

That's by design. The Red Team profile fails closed unless Burp is running on
`127.0.0.1:8080`. OSINT and Puppet Master are confined to the VPN tunnel in the
kernel and will not even open a window without one — run `annixion-vpn-status`
to see why. Start the proxy or connect the VPN, or override enforcement per
[usage.md](usage.md#bypassing-proxy-enforcement-via-user-overrides).

### Red Team won't reach a target on the local network

It should, as of the fix for
[#37](https://github.com/Pyth3rEx/AnNIXion/issues/37) — the profile no longer
requires a VPN tunnel. If it still refuses to launch, you are on an older
version: launch it with `firefox -P "Red Team" --no-remote` in the meantime.

If the window opens but nothing loads, the proxy is the cause rather than the
tunnel. Every request goes through Burp, internal addresses included, so Burp
has to be running and able to reach the target itself.

### Burp works, but enforced traffic isn't going through the VPN

Burp was probably started from a shell rather than through the slice. Firefox
only talks to loopback, so Burp makes the real requests — outside the enforced
slice its egress is unconfined. When you run a profile through
`annixion-vpn-browser`, start Burp with `annixion-vpn-run burpsuite` too.

### Firefox shows certificate warnings through Burp

Run `annixion-burp-ca` while Burp is running. This fetches Burp's CA and
trusts it via Firefox enterprise policy. Re-run only if Burp regenerates its CA.

### My VPN is up but enforced profiles still refuse to launch

Run `annixion-vpn-status`. If it reports `tunnel: NONE`, the tunnel is not being
recognised; `annixion-vpn-tunnels` lists every interface that qualifies.

Detection needs a tunnel **device type** (WireGuard, tun/tap, PPP, xfrm, …)
*and* a route in some routing table. A tunnel that is up but routes nothing is
rejected deliberately — the killswitch would block all its traffic anyway, which
looks like an unexplained blackhole. Interface *names* are not consulted, so
vendor naming like Mullvad's `ee-tll-wg-001` is fine; if your VPN presents as
some other device type, add its name to
`annixion.vpnEnforcement.tunnelInterfaces` from `user/`.

### Enforced profiles hang and time out instead of loading

A hang means something different from a block. The killswitch rejects with ICMP
admin-prohibited, so a genuinely blocked connection fails in under a
millisecond. One that hangs until it times out means the inner packet was
accepted but the encrypted packet carrying it never reached the wire — the
tunnel's own egress being blocked rather than your browsing.

```console
$ annixion-vpn-run curl --max-time 8 http://<a LAN address>/   # should fail in ~0ms
$ annixion-vpn-run curl --max-time 8 https://9.9.9.9/          # should not hang
```

Instant failure on the first with a hang on the second confirms it.

### Firefox can't connect to the DoH resolver, and nothing loads

DoH runs in TRR-only mode with no plaintext fallback, so
`network.trr.bootstrapAddr` must hold an IP of the host in `network.trr.uri`.
If it is missing or names a different host, Firefox cannot resolve its own
resolver and the profile has no DNS at all. Check both agree in `about:config` —
and note the pref is `bootstrapAddr` since Firefox 89, the older
`bootstrapAddress` being silently ignored.

Red Team and OSINT use unfiltered Quad9 while Puppet Master uses the
blocklisted service, so a domain resolving in one profile may legitimately
NXDOMAIN in another.

---

## CI & contributing

### `gh auth login` worked, but pushing still can't authenticate

AnNIXion wires the gh credential helper into `/etc/gitconfig` for every user
(`modules/git.nix`), so `gh auth login` is the only step there is.

Do not run `gh auth setup-git`. It writes the store path of whichever `gh` ran
it into your `~/.gitconfig`, and the next garbage collection deletes that path.
The helper then fails to start — `git push` prints
`.gh-wrapped auth git-credential get: No such file or directory` and falls back
to asking for a password nobody has.

`~/.gitconfig` overrides `/etc/gitconfig`, so a machine that has already been
through that needs the stale line removed:

```bash
git config --global --unset-all credential.https://github.com.helper
git config --global --unset-all credential.https://gist.github.com.helper
```

### CI rejects my PR for committing `hardware-configuration.nix`

It's machine-specific and gitignored. Remove it from your commit; CI and the dev
shell generate a stub from `ci/hardware-stub.nix` automatically. See
[dev.md](dev.md) and [CONTRIBUTING.md](../CONTRIBUTING.md).

### CI fails on a version bump

Only the `dev` → `main` merge needs a `VERSION` bump, and the maintainer owns
it. Don't bump `VERSION` in feature PRs against `dev`.

### The ISO build fails the size gate

The release ISO must stay under 1900 MB — the GitHub release asset limit. Trim
added packages or move heavy tooling behind an optional module rather than the
base ISO. The gate runs only on PRs into `main` and on pushes to `main`.
