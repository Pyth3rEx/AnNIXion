# Security status — AnNIXion 0.5.1

`2026-11-23 18:13 UTC` · coverage `full` · closure 2701 store paths, 25.53 GiB

Generated. Do not edit by hand.

| Page | Contents |
|---|---|
| [CVEs](cves.md) | 947 findings, **0 actionable**, across 111 packages |
| [Packages](packages.md) | 2253 in the installed closure |
| [Applications](apps.md) | 328 declared in `systemPackages` |

## Findings by severity

| | 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low | ⚪ Ungraded | Total |
|---|---:|---:|---:|---:|---:|---:|
| **[Fix in nixpkgs](cves.md)** | 0 | 0 | 0 | 0 | 0 | **0** |
| **[Fixed upstream](cves.md)** | 0 | 0 | 0 | 0 | 0 | **0** |
| [No fix](cves.md) | 0 | 0 | 0 | 0 | 0 | 0 |
| [Unclassified](cves.md) | 33 | 269 | 467 | 50 | 128 | 947 |
| [Not applicable](cves.md) | 0 | 0 | 0 | 0 | 0 | 0 |
| Total | 33 | 269 | 467 | 50 | 128 | 947 |

## Highest

| | CVE | CVSS | Package | Class |
|---|---|---|---|---|
| Actionable | — | — | — | — |
| Any | [CVE-2026-111497](https://nvd.nist.gov/vuln/detail/CVE-2026-111497) | 🔴 9.8 Critical | `powershell` | including not-applicable |

## Maintainer coverage

Packages nobody in nixpkgs has signed up for. A fix landing upstream does not reach us unless somebody here notices. Packages defined in this repository are counted separately — they are ours, not orphaned.

| | Count |
|---|---:|
| nixpkgs applications with no maintainer | 43 / 310 |
| Applications defined in this repo | 18 |
| Flagged packages with no maintainer | 37 / 111 |

Flagged and unmaintained: `alsa-lib`, `avahi`, `bison`, `bluez`, `boost`, `cairo`, `cpio`, `cups`, `dash`, `dhcpcd`, `dmg2img`, `game-music-emu`, `giflib`, `inetutils`, `jbig2dec`, `libcaca`, `libcap`, `libical`, `libmad`, `libraw`, `libsndfile`, `libssh`, `libupnp`, `libvpx`, `lua`, `md4c`, `nghttp2`, `oh-my-zsh`, `openjpeg`, `orc`, `p11-kit`, `pixman`, `pulseaudio`, `shaderc`, `snappy`, `speex`, `xdg-utils`

## Caveats

- Three engines, low overlap: 89 CVEs common to vulnix and grype out of 458 and 192. The `Engines` column says which saw what.
- Presence, not reachability. Services `hardening.nix` disables still appear.
- ~13% of CPEs sbomnix emits are malformed and skipped by grype, systemd among them.
- Build-time inputs are excluded; they ship in the release's supply-chain page.
- Exact for this tag only. The closure is pinned by `flake.lock`.

Report privately via [security advisories](https://github.com/Pyth3rEx/AnNIXion/security/advisories).
