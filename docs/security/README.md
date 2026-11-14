# Security status — AnNIXion 0.4.3

`2026-10-26 13:28 UTC` · coverage `full` · closure 2660 store paths, 24.27 GiB

Generated. Do not edit by hand.

| Page | Contents |
|---|---|
| [CVEs](cves.md) | 657 findings, **392 actionable**, across 107 packages |
| [Packages](packages.md) | 2206 in the installed closure |
| [Applications](apps.md) | 313 declared in `systemPackages` |

## Findings by severity

| | 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low | ⚪ Ungraded | Total |
|---|---:|---:|---:|---:|---:|---:|
| **[Fix in nixpkgs](cves.md)** | 53 | 185 | 98 | 25 | 0 | **361** |
| **[Fixed upstream](cves.md)** | 3 | 3 | 12 | 13 | 0 | **31** |
| [No fix](cves.md) | 0 | 9 | 23 | 4 | 3 | 39 |
| [Unclassified](cves.md) | 7 | 21 | 12 | 1 | 0 | 41 |
| [Not applicable](cves.md) | 11 | 46 | 64 | 9 | 55 | 185 |
| Total | 74 | 264 | 209 | 52 | 58 | 657 |

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
| Flagged packages with no maintainer | 34 / 107 |

Flagged and unmaintained: `alsa-lib`, `avahi`, `bison`, `bluez`, `cairo`, `cpio`, `cups`, `dash`, `dhcpcd`, `dmg2img`, `game-music-emu`, `giflib`, `inetutils`, `jbig2dec`, `libcaca`, `libcap`, `libical`, `libmad`, `libraw`, `libsndfile`, `libssh`, `libupnp`, `libvpx`, `lua`, `md4c`, `nghttp2`, `oh-my-zsh`, `openjpeg`, `orc`, `p11-kit`, `pixman`, `pulseaudio`, `shaderc`, `snappy`

## Caveats

- Three engines, low overlap: 89 CVEs common to vulnix and grype out of 458 and 192. The `Engines` column says which saw what.
- Presence, not reachability. Services `hardening.nix` disables still appear.
- ~13% of CPEs sbomnix emits are malformed and skipped by grype, systemd among them.
- Build-time inputs are excluded; they ship in the release's supply-chain page.
- Exact for this tag only. The closure is pinned by `flake.lock`.

Report privately via [security advisories](https://github.com/Pyth3rEx/AnNIXion/security/advisories).
