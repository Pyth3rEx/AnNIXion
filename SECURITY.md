# Security Policy

## Intended use

AnNIXion is an **offensive security distribution** — it ships tools built to
scan, fuzz, intercept, brute-force, and exploit. Use it only against systems
you own or have **explicit written authorization** to test. The authors assume
no liability for misuse.

This document describes the project's own security posture and how to report a
vulnerability in AnNIXion itself.

---

## Current security posture

AnNIXion optimizes for a capable, reproducible operator workstation. An attack
surface reduction pass has landed, but it is **not** an anonymity-focused
distribution and does not claim to be hardened against an attacker who already
has local code execution. Be deliberate about where you run it and what it can
reach.

**What is configured**

- Attack surface reduction — `modules/hardening.nix` disables OpenSSH,
  ModemManager, geoclue, fwupd, the KDE PIM stack and the rest of what the
  distro does not use; enables the firewall with no ports open; sets kernel
  sysctls covering `dmesg`, kernel pointers, kexec, unprivileged BPF, `ptrace`
  and ICMP redirects; and blacklists uncommon network protocols and exotic
  filesystems. Everything is applied at priority 900, so a single line in
  `user/configuration.nix` restores any of it. See
  [docs/hardening.md](docs/hardening.md), which also records what was
  deliberately left alone and why.
- Non-root `operator` user; `sudo` gated behind the `wheel` group
  (`security.sudo.wheelNeedsPassword` defaults to requiring a password on the
  installed system).
- Browser isolation and proxy enforcement: each Firefox profile fails closed if
  its assigned proxy is not running, so traffic does not leak to a direct
  connection by default. OSINT and Puppet Master are confined to a VPN tunnel in
  the kernel and refuse to launch without one; Red Team fails closed on Burp
  instead, and is deliberately **not** tunnel-gated, since it has to reach
  internal targets (#37).
- Burp CA handled out of band via `annixion-burp-ca` and Firefox enterprise policy — no
  system-wide trust store modification.
- Machine-specific material (`hardware-configuration.nix`, `assets/certs/`) is
  gitignored and never committed.

**What is NOT hardened yet**

Part of **Phase 10** in [docs/roadmap.md](docs/roadmap.md) is still open. In
particular, the following are **not** applied out of the box:

- No full-disk encryption. The installer does not offer it yet, so the disk is
  readable by anyone holding the machine.
- No MAC randomization or IPv6 privacy extensions configured by default.
- `kernel.unprivileged_userns_clone` is **not** set to 0, and
  `security.lockKernelModules` is off. Both are standard hardening steps, and
  both break things AnNIXion depends on — bubblewrap and Firefox's sandbox for
  the first, WireGuard device creation for the second.
- No systemd unit sandboxing on the services that remain, xrdp included.
- The live ISO grants the `operator` **passwordless sudo** so the guided
  installer can run — this is a property of the *installer environment*, not the
  installed system.
- Every install ships the same `hashedPassword` for `operator` until it is
  changed. Set your own in `user/configuration.nix`.

Harden per deployment through the `user/` override system — see
[docs/customization.md](docs/customization.md).

---

## Supported versions

AnNIXion is pre-1.0 and under active development. Only the **latest release**
(and the `dev` branch) receive fixes. Version is tracked in the `VERSION` file
and mirrored in the GitHub release tag.

---

## What a release tells you about itself

Every release carries three files describing its own contents, plus a
`SHA256SUMS` covering them and the ISO. The closure is fixed by the tag's
`flake.lock`, so all of this is exact rather than approximate — and it is
captured at release time because it stops being recoverable later, once
binary-cache entries are collected and upstream sources move.

| Asset | What it describes |
|---|---|
| `annixion-<version>.cdx.json` | The **installed** closure: every package and version present on a running system. |
| `annixion-<version>.buildtime.cdx.json` | The same, plus every toolchain, source archive and patch that produced it. |
| `annixion-<version>.supply-chain.md` | Both, rendered as a page, in two halves. |

Closure size and store-path count are measured per release and carried in the
SBOMs themselves, so an archived artifact still reports the closure it came from
once the release page is the only other record.

**Point a scanner at the first one.** The build closure is provenance, not
exposure: a CVE against a compiler that produced the image is not running on
your machine, is not reachable by an attacker, and is not grounds to treat the
release as vulnerable. The two are published separately, and counted
separately, for exactly that reason.

None of this is a verdict. Nothing here claims the release is free of known
vulnerabilities; the SBOM is what lets you check that yourself, against a
scanner you chose:

```bash
grype sbom:annixion-<version>.cdx.json
```

Note what such a scan does *not* know: it sees what is present, not what is
reachable. Findings against services this system disables (see the hardening
notes above) are still findings, and some CPE ranges upstream are simply stale.

---

## Reporting a vulnerability

If you find a security issue **in AnNIXion's configuration or tooling** (not in
the third-party tools it packages):

- **Do not** open a public issue.
- Use GitHub's private **Security → Report a vulnerability** advisory flow on
  the [repository](https://github.com/Pyth3rEx/AnNIXion/security/advisories), or
  contact the maintainer directly.
- Include the affected version, a description, and reproduction steps.

Vulnerabilities in the upstream tools themselves should be reported to their
respective projects.
