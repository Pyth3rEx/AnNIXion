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

AnNIXion optimizes for a capable, reproducible operator workstation. It is
**not** a hardened or anonymity-focused distribution today, tho it plans to be by version 1.0. Be deliberate about
where you run it and what it can reach.

**What is configured**

- Non-root `operator` user; `sudo` gated behind the `wheel` group
  (`security.sudo.wheelNeedsPassword` defaults to requiring a password on the
  installed system).
- Browser isolation and proxy enforcement: the Red Team / OSINT / Puppet Master
  Firefox profiles fail closed if their assigned proxy (Burp / VPN) is not
  running, so traffic does not leak to a direct connection by default.
- Burp CA handled out of band via `annixion-burp-ca` and Firefox enterprise policy — no
  system-wide trust store modification.
- Machine-specific material (`hardware-configuration.nix`, `assets/certs/`) is
  gitignored and never committed.

**What is NOT hardened yet**

The items in **Phase 10** of [docs/roadmap.md](docs/roadmap.md) are open. In
particular, the following are **not** applied out of the box:

- No kernel hardening sysctls (`dmesg_restrict`, `kptr_restrict`,
  `unprivileged_userns_clone`, `ptrace_scope`).
- No MAC randomization or IPv6 privacy extensions configured by default.
- The live ISO grants the `operator` **passwordless sudo** so the guided
  installer can run — this is a property of the *installer environment*, not the
  installed system.
- OpenSSH is enabled with password authentication permitted. Disable it or
  switch to key-only auth via `user/configuration.nix` if the box is reachable.
- The firewall is left at NixOS defaults; no deny-by-default ruleset is declared.

Harden per deployment through the `user/` override system — see
[docs/customization.md](docs/customization.md).

---

## Supported versions

AnNIXion is pre-1.0 and under active development. Only the **latest release**
(and the `dev` branch) receive fixes. Version is tracked in the `VERSION` file
and mirrored in the GitHub release tag.

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
