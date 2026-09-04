<div align="center">

# AnNIXion

![AnNIXion banner](assets/branding/banner.png)

**The environment for operators who refuse to wing it.**

[![Version](https://img.shields.io/github/v/release/Pyth3rEx/AnNIXion?style=flat-square&label=version&color=2EA043&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAWCAMAAACWh252AAAAnFBMVEX///+9vb2+trbNyMjt7Oy3trZoFBRzHh7JyMjHv79qCgpfCAipmpppZ2eZkZGRgICXioq7urq9vLzx8fH29vbn5ubVyclQCgqNcXGGbW14VFSZamq4mppTCQlgGBh6QECIVFR4MDBmGRnYyMjBpKRuEBCreXmBLCxlBwdvJyeNYWFzPj6BRUV8LS3m399hEBBsCQmKFRXy8PCiiIhhszV1AAAAAXRSTlMAQObYZgAAASZJREFUKM9tko12gjAMhUspMxZoLZa5ISqCf6CI4vu/20rwAEO+c6BA0nBvUkIQizZ3mzlfM5jPOOeuy8kQz8dFCCIXgkygAixBGQBTUwkSQOLDUocT4QAM8yCgUobs+zO++vF/ET+K1nG02WyjLUpc9Tm7JNmn2zRN19lhf0xOZ3dUxMnopWV2iPPFouCrhl7jQJqS1+g29pBlQ2/leRi0GWP6fsorQ9u8x/N5fFTVIKHWdZx3H3jVMihimkPVSPbFXF0O08oKil7kqAVE6SWhQN9vFF4fnaxxFq+82VUIUZRlyTvQZVMGHGX8MEcik+OkUNc6XDIQu4mBWgAWCrKnxt38wRMeFg7tsQkEoLh5XmFOItXs6rqYYKbVnczm0L6tCvpv6x9FEReRd286IAAAAABJRU5ErkJggg==)](https://github.com/Pyth3rEx/AnNIXion/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Pyth3rEx/AnNIXion/total?style=flat-square&color=2EA043&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/releases)
[![Stars](https://img.shields.io/github/stars/Pyth3rEx/AnNIXion?style=flat-square&color=E3B341&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/stargazers)
[![CI](https://img.shields.io/github/actions/workflow/status/Pyth3rEx/AnNIXion/ci.yml?style=flat-square&label=CI&logo=githubactions&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=gnu&logoColor=white)](LICENSE)
<br>
[![NixOS](https://img.shields.io/badge/NixOS-26.05-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Flakes](https://img.shields.io/badge/flakes-enabled-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-5277C3?style=flat-square&logo=linux&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion)
<br>
[![Last commit](https://img.shields.io/github/last-commit/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/commits/main)
[![Commit activity](https://img.shields.io/github/commit-activity/m/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/graphs/commit-activity)
[![Issues](https://img.shields.io/github/issues/Pyth3rEx/AnNIXion?style=flat-square&color=D29922&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/issues)
[![Pull requests](https://img.shields.io/github/issues-pr/Pyth3rEx/AnNIXion?style=flat-square&color=8957E5&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/pulls)

[**Installation**](docs/installation.md) · [**Usage**](docs/usage.md) · [**Customization**](docs/customization.md) · [**Roadmap**](docs/roadmap.md)

</div>

---

AnNIXion is a NixOS-based offensive security distribution for red teamers, OSINT
practitioners and persona operators. Every tool, browser profile, proxy rule,
menu entry and desktop shortcut is declared in code — so the machine you assess
from is version-controlled, reproducible, and rebuilt from a single command
instead of assembled by hand and slowly drifting.

The name comes from *annexion* — to take full control of a territory, absorb it
completely, make it yours.

> Built on NixOS and proud of the lineage, but **not affiliated with, endorsed
> by or connected to** the NixOS Foundation or the Nix project.

---

## What you get

**A workstation that fails closed.** The OSINT and Puppet Master browser
profiles run inside a dedicated systemd slice, and an nftables rule matching
that cgroup permits egress only through a live tunnel. The enforcement is in the
kernel, not in browser preferences, so WebRTC, OCSP and captive-portal probes
are covered too — and if the tunnel drops, traffic stops rather than falling
back to your real address.

**Four browsers that cannot contaminate each other.** Separate cookies, cache,
extensions, search engines and egress path, each generated from configuration
rather than clicked together once and forgotten.

```
Firefox — Red Team        → Burp at 127.0.0.1:8080, fails closed
Firefox — OSINT           → VPN tunnel, kernel-enforced
Firefox — Puppet Master   → VPN tunnel, kernel-enforced, container identities
Firefox — Unsafe Browser  → direct, for captive portals only
```

Burp's CA is fetched and trusted on first install, so interception works without
the usual certificate dance.

**The toolset, in kill-chain order.** Nmap, Metasploit, Burp Suite, SQLMap,
Gobuster, ffuf, Hydra, John, Hashcat, Aircrack-ng, Ghidra, Binwalk, Impacket,
Volatility 3, Autopsy, Wireshark, theHarvester, HackRF, GQRX and GNU Radio —
filed under Reconnaissance, Weaponization, Delivery, Exploitation, C2,
Post-Exploitation, Forensics and RE rather than one flat "Security" menu.

**A desktop that is part of the configuration.** KDE Plasma 6 with Krohnkite
tiling, a drawn icon set where the colour of a mark tells you what running that
tool does to a target, Hyper-V Enhanced Session over vsock, and a ZSH
environment with oh-my-posh, fzf history and syntax highlighting.

**An override system, so none of this is a fork.** Every base option is
`lib.mkDefault`; anything you put in `user/` wins without `lib.mkForce`. Your
hostname, your keys, your extra tools, your relaxations of the hardening — all
without touching a tracked file.

---

## New in 0.4 "Nebula"

**Every release says what is inside it.** Each one ships a CycloneDX SBOM of the
installed closure, a second covering the toolchains and sources that produced
it, a readable supply-chain page, and a `SHA256SUMS` over the lot. The two are
published and counted separately on purpose: a CVE against a compiler that built
the image is not running on your machine. Point your own scanner at it —
`grype sbom:annixion-<version>.cdx.json` — because none of it is a verdict, it
is the material to reach your own.

**Known-vulnerability status, kept current.** A weekly scan republishes the CVE
status of the shipped closure, and it only commits when something actually
changed, so the page's date means something.

**Pull requests are scanned for what they add.** A PR that pulls in a new
dependency with a known CVE is told so on the PR, scoped to what the branch
introduces rather than re-reporting the whole closure.

**Rootless containers.** Docker runs as the desktop user, with no `docker`
group — which is root-equivalent — and no root daemon by default.

**One file per tool.** A tool's package, its menu entry and its icon are
declared together in [`catalog/`](catalog/); the package list, the `.desktop`
entry, the menu tree and the icon theme are all derived from it. Adding a tool
is adding a file, and the three can no longer drift apart.

---

## Why NixOS

|  | Traditional distro | AnNIXion |
|---|:---:|:---:|
| Configuration drift | Inevitable | Impossible |
| Reinstall | Hours of manual setup | One command |
| Browser isolation | Manual, breaks over time | Enforced by policy |
| Proxy kill-switch | None | Built in — leaks blocked by default |
| Burp CA setup | Manual, every install | Generated, trusted on first boot |
| Roll back a bad change | Not possible | Boot the previous generation |
| Share your exact setup | Zip file and prayer | `git clone` |

---

## Quick start

**Fresh install — no NixOS required:**

1. Download the latest ISO from [Releases](https://github.com/Pyth3rEx/AnNIXion/releases/latest)
2. Flash to USB with [Rufus](https://rufus.ie) (Windows) or `dd` (Linux/macOS)
3. Boot — it auto-logs in as `operator`
4. Connect with `nmtui`, then run `annixion-install`

**On existing NixOS:**

```bash
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/
git -C ~/.dotfiles add hardware-configuration.nix -f
sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure
```

After the first build, `rebuild`, `upgrade` and `update` are available from the
shell. Security tools are large — expect 30–60 minutes on a slow connection.
Full guide, including Hyper-V Enhanced Session:
[docs/installation.md](docs/installation.md).

---

## Documentation

| | |
|---|---|
| [Installation](docs/installation.md) | Prerequisites, deploy steps, Hyper-V setup |
| [Usage](docs/usage.md) | Commands, browser profiles, Burp and VPN setup |
| [Architecture](docs/architecture.md) | How the tree is laid out, and how to add a tool |
| [Customization](docs/customization.md) | The user override system, adding tools, dev environment |
| [Shell reference](docs/zsh.md) · [CLI tools](docs/tools.md) | Prompt, keybindings, aliases · the enhanced toolset |
| [Hardening](docs/hardening.md) | What is disabled to reduce attack surface, and how to restore it |
| [Visual identity](docs/visual-identity.md) | Palette, typography, the mark system |
| [Developer guide](docs/dev.md) · [Testing](docs/testing.md) | Local CI levels · the suite and the rule behind it |
| [FAQ](docs/faq.md) · [Roadmap](docs/roadmap.md) | Troubleshooting · phase-by-phase progress |
| [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) | How to contribute · posture, SBOMs and reporting |

---

## Status

Active development, functional and deployable today. Shipping **0.3.1
"Tripwire"**; **0.4.0 "Nebula"** is in progress.

Every pull request runs flake evaluation, a full system closure build, and VM
tests covering boot, tool presence and killswitch regressions; releases build
the ISO behind a size gate. Full disk encryption, a TUI installer and kernel
hardening are the notable gaps — see [docs/roadmap.md](docs/roadmap.md).

---

<div align="center">

**For authorized security testing, research and educational use only.**
Obtain explicit written permission before any assessment. The authors assume no
liability for misuse.

</div>
