# Security status — AnNIXion 0.4.3

`2026-10-05 14:55 UTC` · coverage `full` · closure 2660 store paths, 24.27 GiB

Generated. Do not edit by hand.

| Page | Contents |
|---|---|
| [CVEs](cves.md) | 281 findings, **116 actionable**, across 76 packages |
| [Packages](packages.md) | 2206 in the installed closure |
| [Applications](apps.md) | 313 declared in `systemPackages` |

## Findings by severity

| | 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low | ⚪ Ungraded | Total |
|---|---:|---:|---:|---:|---:|---:|
| **[Fix in nixpkgs](cves.md)** | 5 | 73 | 28 | 2 | 0 | **108** |
| **[Fixed upstream](cves.md)** | 3 | 3 | 2 | 0 | 0 | **8** |
| [No fix](cves.md) | 1 | 7 | 3 | 1 | 3 | 15 |
| [Unclassified](cves.md) | 1 | 3 | 4 | 0 | 0 | 8 |
| [Not applicable](cves.md) | 9 | 34 | 42 | 9 | 48 | 142 |
| Total | 19 | 120 | 79 | 12 | 51 | 281 |

## Highest

| | CVE | CVSS | Package | Class |
|---|---|---|---|---|
| Actionable | [CVE-2026-40962](https://nvd.nist.gov/vuln/detail/CVE-2026-40962) | 🔴 9.8 Critical | `ffmpeg` | has a fix |
| Any | [CVE-2026-63073](https://nvd.nist.gov/vuln/detail/CVE-2026-63073) | 🔴 9.8 Critical | `openssl` | including not-applicable |

## Maintainer coverage

Packages nobody in nixpkgs has signed up for. A fix landing upstream does not reach us unless somebody here notices. Packages defined in this repository are counted separately — they are ours, not orphaned.

| | Count |
|---|---:|
| nixpkgs applications with no maintainer | 44 / 301 |
| Applications defined in this repo | 12 |
| Flagged packages with no maintainer | 25 / 76 |

Flagged and unmaintained: `alsa-lib`, `avahi`, `bison`, `bluez`, `cairo`, `cpio`, `dmg2img`, `giflib`, `inetutils`, `jbig2dec`, `libcaca`, `libcap`, `libmad`, `libraw`, `libssh`, `libupnp`, `libvpx`, `lua`, `md4c`, `nghttp2`, `openjpeg`, `p11-kit`, `pixman`, `pulseaudio`, `shaderc`

## Caveats

- Three engines, low overlap: 89 CVEs common to vulnix and grype out of 458 and 192. The `Engines` column says which saw what.
- Presence, not reachability. Services `hardening.nix` disables still appear.
- ~13% of CPEs sbomnix emits are malformed and skipped by grype, systemd among them.
- Build-time inputs are excluded; they ship in the release's supply-chain page.
- Exact for this tag only. The closure is pinned by `flake.lock`.

Report privately via [security advisories](https://github.com/Pyth3rEx/AnNIXion/security/advisories).
