# Hardening

`modules/hardening.nix` removes services, packages and kernel features AnNIXion
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
| `documentation.nixos`, `.info`, `.doc` | Offline manuals. **Man pages stay** — this is a tooling distro. |
| `environment.stub-ld` | Loader stub for unpatched foreign binaries. |
| `nix.settings.allowed-users` | Defaulted to `*`, letting any account submit builds. Now `@wheel`. |
| Firewall ports | Nothing listens that should be reachable, so nothing is opened. |

xrdp's `openFirewall` is off in `modules/xrdp.nix` as well: Enhanced Session
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

`udisks2`, `upower` and wifi stay enabled: Plasma's device and battery
integration, and wireless on laptop installs. `polkit` and `pkexec` stay because
Plasma needs them for privileged actions, and the control centre killswitch goes
through polkit.

## Measured effect

Against the same configuration without `modules/hardening.nix`:

| | Baseline | Hardened |
|---|---|---|
| Closure size | 24.57 GiB | 23.71 GiB |
| Store paths | 2746 | 2666 |
| systemd system units | 146 | 139 |

Units removed: `sshd` (and its socket/keygen units), `ModemManager`,
`power-profiles-daemon`, `speech-dispatcherd`.
