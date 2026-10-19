# Security status — AnNIXion 0.4.3

`2026-10-19 13:29 UTC` · coverage `full` · closure 2660 store paths, 24.27 GiB

Generated. Do not edit by hand.

| Page | Contents |
|---|---|
| [CVEs](cves.md) | 603 findings, **342 actionable**, across 102 packages |
| [Packages](packages.md) | 2206 in the installed closure |
| [Applications](apps.md) | 313 declared in `systemPackages` |

## Findings by severity

| | 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low | ⚪ Ungraded | Total |
|---|---:|---:|---:|---:|---:|---:|
| **[Fix in nixpkgs](cves.md)** | 47 | 168 | 77 | 19 | 0 | **311** |
| **[Fixed upstream](cves.md)** | 5 | 8 | 8 | 10 | 0 | **31** |
| [No fix](cves.md) | 0 | 10 | 24 | 4 | 3 | 41 |
| [Unclassified](cves.md) | 7 | 21 | 12 | 1 | 0 | 41 |
| [Not applicable](cves.md) | 11 | 41 | 69 | 9 | 49 | 179 |
| Total | 70 | 248 | 190 | 43 | 52 | 603 |

## Highest

| | CVE | CVSS | Package | Class |
|---|---|---|---|---|
| Actionable | [CVE-2026-19931](https://nvd.nist.gov/vuln/detail/CVE-2026-19931) | 🔴 9.8 Critical | `curl` | has a fix |
| Any | [CVE-2026-106016](https://nvd.nist.gov/vuln/detail/CVE-2026-106016) | 🔴 9.8 Critical | `firefox` | including not-applicable |

## Maintainer coverage

Packages nobody in nixpkgs has signed up for. A fix landing upstream does not reach us unless somebody here notices. Packages defined in this repository are counted separately — they are ours, not orphaned.

| | Count |
|---|---:|
| nixpkgs applications with no maintainer | 44 / 301 |
| Applications defined in this repo | 12 |
| Flagged packages with no maintainer | 32 / 102 |

Flagged and unmaintained: `alsa-lib`, `avahi`, `bison`, `bluez`, `cairo`, `cpio`, `cups`, `dash`, `dhcpcd`, `dmg2img`, `giflib`, `inetutils`, `jbig2dec`, `libcaca`, `libcap`, `libmad`, `libraw`, `libsndfile`, `libssh`, `libupnp`, `libvpx`, `lua`, `md4c`, `nghttp2`, `oh-my-zsh`, `openjpeg`, `orc`, `p11-kit`, `pixman`, `pulseaudio`, `shaderc`, `snappy`

## Caveats

- Three engines, low overlap: 89 CVEs common to vulnix and grype out of 458 and 192. The `Engines` column says which saw what.
- Presence, not reachability. Services `hardening.nix` disables still appear.
- ~13% of CPEs sbomnix emits are malformed and skipped by grype, systemd among them.
- Build-time inputs are excluded; they ship in the release's supply-chain page.
- Exact for this tag only. The closure is pinned by `flake.lock`.

Report privately via [security advisories](https://github.com/Pyth3rEx/AnNIXion/security/advisories).
