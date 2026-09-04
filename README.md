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

**The environment for operators who refuse to wing it.**

AnNIXion is a NixOS-based offensive security distribution for red teamers, OSINT
practitioners and persona operators. Every tool, browser profile, proxy rule,
menu entry and desktop shortcut is declared in code — so the machine you assess
from is version-controlled, reproducible, and rebuilt from a single command
instead of assembled by hand and left to rot.

The name comes from *annexion* — to take full control of a territory, absorb it
completely, make it yours.

> Built on NixOS and proud of the lineage, but **not affiliated with, endorsed
> by or connected to** the NixOS Foundation or the Nix project.

---

## Your egress cannot leak

A VPN that drops is not an inconvenience on an engagement, it is an incident.
So the killswitch is not a browser setting or a checkbox in a client — it is an
nftables rule in the kernel.

The OSINT and Puppet Master profiles run inside a dedicated systemd slice, and
that rule permits egress only through a live tunnel. WebRTC, OCSP, captive
portal probes and anything else the browser does behind your back are all
covered, because none of them can escape a cgroup. If the tunnel dies, traffic
stops. There is no fallback to your real address, because there is nothing to
fall back to.

Red Team is deliberately not confined — it has to reach the LAN as often as the
internet — but it still fails closed on Burp, and one command puts it in the
tunnel when you want it there.

## Your identities cannot cross

Four Firefox profiles, each with its own cookies, cache, extensions, search
engines and egress path. Not four windows of the same browser. Not four
profiles you set up once and hoped stayed separate.

```
Firefox — Red Team        → Burp at 127.0.0.1:8080, fails closed
Firefox — OSINT           → VPN tunnel, kernel-enforced
Firefox — Puppet Master   → VPN tunnel, kernel-enforced, container identities
Firefox — Unsafe Browser  → direct, for captive portals only
```

Burp's CA is fetched and trusted on first install, so interception works
immediately instead of after the usual certificate ritual.

## Your machine is a file

A new laptop, a fresh VM, a rebuilt box after an engagement — one clone and one
command, and it is the same machine down to the shell prompt. Configuration
drift is not managed, it is impossible: the system is the flake, and anything
not in the flake is not on the system.

A change that breaks something is undone by booting the previous generation.
Nothing is uninstalled, nothing is repaired, you just boot last week.

And it is yours without being a fork: every base option is `lib.mkDefault`, so
whatever you put in `user/` wins without touching a tracked file.

## You know what is in it

Most distributions ask you to trust them. This one hands you the evidence.

Every release ships a CycloneDX SBOM of the installed closure, a second covering
the toolchains and sources that built it, a readable supply-chain page, and
checksums over all of it. The two closures are published and counted separately
on purpose — a CVE in a compiler that produced the image is not running on your
machine, and conflating them turns a security document into noise.

Point your own scanner at it. `grype sbom:annixion-<version>.cdx.json`. None of
it is a verdict; it is the material for you to reach one.

You do not have to run one to look, either. A weekly scan republishes the state
of the shipped closure, kept in three pages you can read right now:

| | |
|---|---|
| [Known CVEs](docs/security/cves.md) | What is currently reported against the closure, and what has no fix upstream yet |
| [Packages](docs/security/packages.md) | Every package on a running system, with its version |
| [Applications](docs/security/apps.md) | The tools this distribution chose to ship, and their standing |

A pull request that introduces a new CVE is told so on the pull request, before
it merges.

## It is a desktop, not a toolbox

Nmap, Metasploit, Burp Suite, SQLMap, Gobuster, ffuf, Hydra, John, Hashcat,
Aircrack-ng, Ghidra, Binwalk, Impacket, Volatility 3, Autopsy, Wireshark,
theHarvester, HackRF, GQRX and GNU Radio — filed under Reconnaissance,
Weaponization, Delivery, Exploitation, C2, Post-Exploitation, Forensics and
Reverse Engineering, so the menu follows the work instead of dumping ninety
binaries under "Security".

Every tool is drawn, not scraped from an icon pack: the colour of a mark tells
you what running it does to a target — passive, probing, offensive, forensic.
KDE Plasma 6 with Krohnkite tiling, Hyper-V Enhanced Session over vsock, and a
ZSH environment with oh-my-posh, fzf history and syntax highlighting.

Containers run rootless — as you, with no `docker` group, because that group is
root by another name.

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
| Know what is installed | Guesswork | SBOM, per release |
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
shell. The toolset is large — expect 30–60 minutes on a slow connection. Full
guide, including Hyper-V Enhanced Session:
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
| [FAQ](docs/faq.md) · [Roadmap](docs/roadmap.md) | Troubleshooting · what is done and what is planned |
| [Security status](docs/security/README.md) | Known CVEs, the package list and the shipped applications, refreshed weekly |
| [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) | How to contribute · posture, SBOMs and reporting |

---

<div align="center">

**For authorized security testing, research and educational use only.**
Obtain explicit written permission before any assessment. The authors assume no
liability for misuse.

</div>
