# Hardening

`system/hardening.nix` removes services, packages and kernel features AnNIXion
does not need, so what remains is what it actually uses.

## Restoring anything

Every setting is applied at priority 900. That beats the `lib.mkDefault` several
of them carry upstream, while still losing to a plain assignment in
`user/configuration.nix` (priority 100). Restoring something is one line, and
never needs `lib.mkForce`:

```nix
# user/configuration.nix
services.openssh.enable = true;
```

## What is disabled

| Setting | Why |
|---|---|
| `services.openssh` | Was the only remotely reachable service, on `0.0.0.0:22` with password authentication. The desktop arrives over xrdp, and the hypervisor console is the recovery path. |
| `networking.modemmanager` | Probes serial and USB devices. NetworkManager enables it whether or not a modem exists. |
| `services.orca`, `services.speechd` | Plasma enables the Orca screen reader by default, which pulls in speech-dispatcher and the at-spi2 bus — three daemons. **This is an accessibility feature**: set `services.orca.enable = true;` and the other two follow. |
| `services.power-profiles-daemon` | Laptop power profiles. |
| `environment.defaultPackages` | Was `perl`, `rsync`, `strace`. None are needed to boot or run. |
| `documentation.nixos`, `.info`, `.doc` | Offline manuals. **Man pages stay** — this is a tooling distro, so only the three sub-switches are set. `documentation.enable` is the master gate and takes man pages with it. |
| `programs.kde-pim` | Plasma enables it by default, putting `akonadi` and `kdepim-runtime` on PATH — a database and agents speaking IMAP, EWS, Google, Kolab and DAV, with no mail client to use them. |
| `environment.plasma6.excludePackages` | `krdp` (a second RDP server beside xrdp), `plasma-browser-integration` (bridges the desktop into the browser through a native messaging host), `ffmpegthumbs` (parses whatever video a directory holds), `elisa`, `khelpcenter`, the wallpaper pack, the touch keyboard. |
| Baloo indexing | Indexing file contents means parsing them. Set in `home/desktop/plasma.nix`. |
| `environment.stub-ld` | Loader stub for unpatched foreign binaries. |
| `nix.settings.allowed-users` | Defaulted to `*`, letting any account submit builds. Now `@wheel`. |
| Firewall ports | Nothing listens that should be reachable, so nothing is opened. |

The **NUR** flake input was removed: it was declared and referenced nowhere, so
it pinned a community package collection into the lock file and every evaluation
for nothing.

xrdp's `openFirewall` is off in `system/xrdp.nix` as well: Enhanced Session
arrives over vsock, so the TCP port was open with nothing behind it. Bare-metal
RDP over TCP needs it set back to `true`.

## Kernel

`security.protectKernelImage` is on, along with sysctls covering `dmesg`,
kernel pointers, kexec, unprivileged BPF, source routing and ICMP redirects.
`kernel.yama.ptrace_scope = 1` restricts `ptrace` to a debugger's own children —
`gdb ./target` and `strace -f` still work; attaching to an unrelated running PID
needs root.

Uncommon network protocols (`dccp`, `sctp`, `rds`, `tipc`, `ax25`, …) and exotic
filesystems (`cramfs`, `hfsplus`, …) are blacklisted. `squashfs` and
`usb-storage` are deliberately **not** — the live ISO needs one, removable media
the other.

## What is deliberately left alone

Three of the obvious next steps break things AnNIXion depends on:

- **`security.lockKernelModules`** — blocks module loading after boot, so
  `ip link add type wireguard` fails and VPN enforcement goes with it.
- **`kernel.unprivileged_userns_clone = 0`** — the usual next hardening step,
  and it breaks bubblewrap, which `annixion-vpn-run` uses to confine DNS, along
  with Firefox's own content sandbox.
- **`rp_filter = 1`** — strict reverse-path filtering drops the asymmetric paths
  a policy-routed WireGuard tunnel creates.

`udisks2`, `upower`, wifi and `xdg.portal` stay enabled: Plasma's device and
battery integration, wireless on laptop installs, and the portal the GTK and
Flatpak file choosers go through. Plasma sets `udisks2` and `xdg.portal` at
normal priority, so priority 900 cannot move them in any case — it would take
`mkForce`, and the result would be no USB mounting and a broken file chooser.
`polkit` and `pkexec` stay because Plasma needs them for privileged actions, and
the control centre killswitch goes through polkit.

`konsole`, `kate`, `dolphin`, `ark`, `okular`, `gwenview` and `spectacle` stay:
the panel launches some, the zsh aliases edit with `kate`, and the rest are how
you read what you collect.

## Docker

`system/docker.nix` runs the daemon **rootless** — as the desktop user, not as
root. That is the whole reason the module exists rather than a one-line
`virtualisation.docker.enable = true`.

A rootful daemon listens on a socket owned by root, and everyone who may talk to
it is in the `docker` group. That group is not a lesser privilege: a member runs
`docker run -v /:/host` and reads or writes the entire filesystem as root, with
no password and no polkit prompt. Adding the operator to it would hand every
process in the session a way around everything else on this page. Rootless keeps
containers at exactly the privilege of the account that started them, and
creates no `docker` group at all.

What rootless costs, and when to give it up:

| Needs rootful | Why |
|---|---|
| `--net=host` against the real host stack | rootless containers live in their own network namespace |
| Binding a port below 1024 | no `CAP_NET_BIND_SERVICE` on the host side |
| Raw sockets — a container running `nmap -sS`, `arpspoof`, a sniffer | no `CAP_NET_RAW` on the host interface |

Those are real needs on this machine, so the escape hatch is one line:

```nix
# user/configuration.nix
annixion.docker.rootless = false;
```

It enables the root daemon and puts the operator in the `docker` group. Take it
when a container genuinely needs the host network — not to make a permission
error go away.

**Containers are outside the VPN killswitch.** `system/vpn-enforcement.nix`
matches one cgroup, `annixion-vpn.slice` under the user manager, and arms
nftables against it. A container is not in that cgroup under either daemon:
rootful containers sit under `system.slice`, and even the rootless daemon runs
as its own user unit rather than inside the enforced slice. So a container's
traffic leaves through whatever route the host has, tunnel or not, and it keeps
leaving after the tunnel drops. If what runs in the container must be tunnelled,
tunnel it inside the container or start the whole daemon under
`annixion-vpn-run` — do not assume the killswitch reaches it.

## File visibility

A hidden file is one you cannot judge, and this machine exists to handle other
people's artefacts. `home/desktop/file-visibility.nix` turns concealment off in each
place that does it independently:

| Where | How |
|---|---|
| Dolphin | `HiddenFilesShown` in the global view-properties file it reads instead of `dolphinrc` |
| KDE open/save dialogs | `Show Hidden Files` in `kdeglobals` (set in `home/desktop/plasma.nix`) |
| GTK file chooser (Firefox) | `show-hidden` via dconf, for GTK3 and GTK4 |
| `rg` and `fd` | `--hidden`, which they otherwise skip |

`--hidden` still honours `.gitignore`; add `--no-ignore` to
`programs.ripgrep.arguments` if you want that gone too.

**Extensions need no setting.** Dolphin and the KDE dialogs always render the
whole filename — there is no hide-known-extensions behaviour to switch off. The
one thing that still masks a name is a `.desktop` file, which shows its `Name=`
field rather than the filename it has. KDE offers no toggle for this; it answers
it instead by refusing to run a `.desktop` file that is not both executable and
trusted.

## Measured effect

Against the same configuration without `system/hardening.nix`:

| | Baseline | Hardened |
|---|---|---|
| Closure size | 24.57 GiB | 23.36 GiB |
| Store paths | 2746 | 2622 |
| Binaries on PATH | 1477 | 1380 |
| systemd system units | 146 | 136 |

Units removed: `sshd` (and its socket/keygen units), `ModemManager`,
`power-profiles-daemon`, `speech-dispatcherd`, `fwupd` (and its refresh timer),
`geoclue`.
