<div align="center">

# AnNIXion

![AnNIXion banner](banner.png)

**The environment for operators who refuse to wing it.**

[![Version](https://img.shields.io/github/v/release/Pyth3rEx/AnNIXion?style=flat-square&label=version&color=2EA043&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAWCAMAAACWh252AAAAnFBMVEX///+9vb2+trbNyMjt7Oy3trZoFBRzHh7JyMjHv79qCgpfCAipmpppZ2eZkZGRgICXioq7urq9vLzx8fH29vbn5ubVyclQCgqNcXGGbW14VFSZamq4mppTCQlgGBh6QECIVFR4MDBmGRnYyMjBpKRuEBCreXmBLCxlBwdvJyeNYWFzPj6BRUV8LS3m399hEBBsCQmKFRXy8PCiiIhhszV1AAAAAXRSTlMAQObYZgAAASZJREFUKM9tko12gjAMhUspMxZoLZa5ISqCf6CI4vu/20rwAEO+c6BA0nBvUkIQizZ3mzlfM5jPOOeuy8kQz8dFCCIXgkygAixBGQBTUwkSQOLDUocT4QAM8yCgUobs+zO++vF/ET+K1nG02WyjLUpc9Tm7JNmn2zRN19lhf0xOZ3dUxMnopWV2iPPFouCrhl7jQJqS1+g29pBlQ2/leRi0GWP6fsorQ9u8x/N5fFTVIKHWdZx3H3jVMihimkPVSPbFXF0O08oKil7kqAVE6SWhQN9vFF4fnaxxFq+82VUIUZRlyTvQZVMGHGX8MEcik+OkUNc6XDIQu4mBWgAWCrKnxt38wRMeFg7tsQkEoLh5XmFOItXs6rqYYKbVnczm0L6tCvpv6x9FEReRd286IAAAAABJRU5ErkJggg==)](https://github.com/Pyth3rEx/AnNIXion/releases/latest)
[![NixOS](https://img.shields.io/badge/NixOS-26.05-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Flakes](https://img.shields.io/badge/flakes-enabled-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-4A4A4A?style=flat-square&logo=linux&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion)
<br>
[![CI](https://img.shields.io/github/actions/workflow/status/Pyth3rEx/AnNIXion/ci.yml?style=flat-square&label=CI&logo=githubactions&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/actions/workflows/ci.yml)
[![Stars](https://img.shields.io/github/stars/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/stargazers)
[![Last commit](https://img.shields.io/github/last-commit/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/commits/main)
[![License](https://img.shields.io/github/license/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A)](LICENSE)

[**Installation**](docs/installation.md) · [**Usage**](docs/usage.md) · [**Customization**](docs/customization.md) · [**Roadmap**](docs/roadmap.md)

</div>

---

AnNIXion is a NixOS-based offensive security distribution for red teamers, OSINT
practitioners, and persona operators. Every tool, browser profile, proxy rule and
desktop shortcut is declared in code — version-controlled, reproducible, deployed
in a single command.

The name comes from *annexion* — to take full control of a territory, absorb it
completely, make it yours.

---

## Features

- **Kernel-level VPN enforcement.** The OSINT and Puppet Master profiles run in
  a dedicated systemd slice, and an nftables rule matching that cgroup permits
  egress only through a live tunnel. Enforcement is independent of browser
  preferences, so WebRTC, OCSP and captive-portal probes are covered, and
  traffic stops if the tunnel drops.
- **Isolated browser profiles.** Four Firefox profiles, each with its own
  cookies, cache, extensions, search engines and egress path, generated from
  configuration rather than set up by hand.
- **Burp CA automation.** `annixion-burp-ca` fetches Burp's certificate and
  installs it through Firefox enterprise policy. The Red Team profile proxies
  through Burp at profile level and does not fall back to a direct connection
  when the proxy is unavailable.
- **Attack surface reduction.** `modules/hardening.nix` disables unused
  services, trims default packages and sets kernel sysctls. Every setting is
  applied at priority 900, so any of it can be restored with one line in
  `user/`.
- **Reproducible by construction.** The system is one flake: packages, browser
  profiles, egress policy, desktop layout and shell. Deployment and
  redeployment are the same command, and a bad change is undone by booting the
  previous generation.
- **Tested in CI.** Every pull request runs flake evaluation, a full system
  closure build, and VM tests covering boot, tool presence and killswitch
  regressions. Releases additionally build the ISO behind a size gate.

---

## Why NixOS

|  | Traditional distro | AnNIXion |
|---|:---:|:---:|
| Configuration drift | Inevitable | Impossible |
| Reinstall | Hours of manual setup | One command |
| Browser isolation | Manual, breaks over time | Enforced by policy |
| Proxy kill-switch | None | Built in — leaks blocked by default |
| Burp CA setup | Manual every install | Auto-generated, trusted on first boot |
| Roll back a bad change | Not possible | Boot the previous generation |
| Share your exact setup | Zip file and prayer | `git clone` |

---

## What's inside

<table>
<tr>
<td valign="top" width="50%">

**Browsers**
- Red Team — Burp proxy at profile level, FoxyProxy for ad-hoc switching, HackTools, Cookie Editor, SingleFile
- OSINT — VPN-enforced, NoScript, CanvasBlocker, UA Switcher, Cookie AutoDelete, Shodan and Censys search keywords
- Puppet Master — VPN-enforced, Multi-Account Containers, Temporary Containers, per-container identity stripe
- Unsafe Browser — clearnet fallback for captive portals, uBlock and fingerprint resistance only

**Proxy enforcement**
- Browsers block all traffic if their assigned proxy is not running
- Burp CA generated on first install — Firefox trusts it immediately
- Every proxy setting overridable per-machine via `user/`

</td>
<td valign="top" width="50%">

**Offensive tooling**
- Metasploit, Burp Suite, SQLMap, Gobuster, FFuf
- Nmap, Netcat, Wireshark, Hydra, Aircrack-ng
- John the Ripper, Hashcat
- Ghidra, Binwalk
- Volatility 3, Autopsy
- Impacket, WhatWeb

**OSINT & intelligence**
- theHarvester, WHOIS, dig/nslookup

**SDR / RF**
- HackRF tools, GQRX, GNURadio

**Desktop**
- KDE Plasma 6 (X11) with Krohnkite tiling
- Kill-chain application menu, from recon to forensics
- Hyper-V Enhanced Session over vsock
- ZSH + oh-my-posh, fzf history, syntax highlighting

</td>
</tr>
</table>

---

## Browser profiles

Every profile launches isolated — separate cookies, cache, extensions and proxy
rules. Click the desktop launcher. Nothing bleeds between them.

```
┌─────────────────────────────────────────────────────────────────┐
│  Firefox - Red Team          → Burp 127.0.0.1:8080              │
│  Firefox - OSINT             → VPN tunnel (kernel-enforced)     │
│  Firefox - Puppet Master     → VPN tunnel (kernel-enforced)     │
│  Firefox - Unsafe Browser    → Direct (clearnet, no proxy)      │
└─────────────────────────────────────────────────────────────────┘
  OSINT and Puppet Master are confined to the VPN tunnel by an nftables
  killswitch and refuse to launch without one. No fallback. No leaks.

  Red Team is not: it has to reach targets on the LAN as often as on the
  internet. Burp is its control, and still fails closed. Run it through
  the tunnel with  annixion-vpn-browser "Red Team"  when you want that.
```

---

## Quick start

**Fresh install — no NixOS required:**

1. Download the latest ISO from [Releases](https://github.com/Pyth3rEx/AnNIXion/releases/latest)
2. Flash to USB with [Rufus](https://rufus.ie) (Windows) or `dd` (Linux/macOS)
3. Boot — auto-logs in as `operator`
4. Connect: `nmtui`
5. Install: `annixion-install`

**On existing NixOS:**

```bash
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/
git -C ~/.dotfiles add hardware-configuration.nix -f
sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure
```

After the first build, use `rebuild`, `upgrade` or `update` from the shell.

Full guide including Hyper-V Enhanced Session setup →
[docs/installation.md](docs/installation.md)

---

## Documentation

| | |
|---|---|
| [Installation](docs/installation.md) | Prerequisites, deploy steps, Hyper-V setup, repository layout |
| [Usage](docs/usage.md) | Commands, browser profiles, Burp and VPN setup, override examples |
| [Customization](docs/customization.md) | User override system, adding tools, dev environment |
| [Shell reference](docs/zsh.md) | Prompt, keybindings, and the full alias and plugin list |
| [CLI tools](docs/tools.md) | Enhanced command-line tools (bat, rg, fd, fzf, jq…) |
| [Developer guide](docs/dev.md) | Local CI levels, VSCodium tasks, contributor workflow |
| [Hardening](docs/hardening.md) | What is disabled to reduce attack surface, and how to restore it |
| [FAQ](docs/faq.md) | Common setup and troubleshooting questions |
| [Roadmap](docs/roadmap.md) | Phase-by-phase progress, planned features |
| [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) | How to contribute · security posture and reporting |

---

## Status

Active development. Functional and deployable today.

`✔` Bootable ISO with guided installer (`annixion-install`)  
`✔` NixOS flake · Home Manager · plasma-manager  
`✔` KDE Plasma 6 · Krohnkite tiling · Breeze Dark  
`✔` Hyper-V Enhanced Session (vsock)  
`✔` Four Firefox profiles with proxy enforcement and Burp CA automation  
`✔` Kernel-level VPN killswitch with regression tests  
`✔` Offensive, OSINT and SDR tooling declared in a single module  
`✔` Attack surface reduction module  
`✔` ZSH + oh-my-posh environment  
`✔` User override system  
`✔` CI/CD — flake eval, VM tests, ISO build + size gate, versioned releases  

`○` Full disk encryption · TUI installer · Kernel hardening

See [docs/roadmap.md](docs/roadmap.md) for the full picture.

---

<div align="center">

**For authorized security testing, research, and educational use only.**  
Obtain explicit written permission before any assessment. The authors assume no
liability for misuse.

</div>
