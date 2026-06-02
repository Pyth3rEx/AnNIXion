<div align="center">

# AnNIXion

![AnNIXion banner](banner.png)

**The environment for operators who refuse to wing it.**

[![NixOS](https://img.shields.io/badge/NixOS-25.11-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Flakes](https://img.shields.io/badge/flakes-enabled-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-lightgrey?style=flat-square&logo=linux&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion)
[![Stars](https://img.shields.io/github/stars/Pyth3rEx/AnNIXion?style=flat-square&color=yellow&logo=github)](https://github.com/Pyth3rEx/AnNIXion/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/Pyth3rEx/AnNIXion?style=flat-square&logo=github)](https://github.com/Pyth3rEx/AnNIXion/commits/main)
[![License](https://img.shields.io/github/license/Pyth3rEx/AnNIXion?style=flat-square)](LICENSE)

[**Installation**](docs/installation.md) · [**Usage**](docs/usage.md) · [**Customization**](docs/customization.md) · [**Roadmap**](docs/roadmap.md)

</div>

---

AnNIXion is a NixOS-based offensive security distribution for red teamers, OSINT practitioners, and persona operators. Every tool, browser profile, proxy rule, and desktop shortcut is declared in code — version-controlled, reproducible, and deployed in a single command.

The name comes from *annexion* — to take full control of a territory, absorb it completely, make it yours.

---

## Why AnNIXion

Most security distributions are a curated package list dropped on top of a general-purpose OS. You get the tools. You don't get the environment. Configuration drifts. Reinstalls diverge. Your pentest box six months from now is a different machine than it is today.

AnNIXion is different in kind.

|  | Traditional distro | AnNIXion |
|---|:---:|:---:|
| Configuration drift | Inevitable | Impossible |
| Reinstall | Hours of manual setup | One command |
| Browser isolation | Manual, breaks over time | Enforced by policy |
| Proxy kill-switch | None | Built in — leaks blocked by default |
| Burp CA setup | Manual every install | Auto-generated, Firefox trusts it on first boot |
| Roll back a bad change | Not possible | Boot the previous generation |
| Share your exact setup | Zip file and prayer | `git clone` |

---

## What's inside

<table>
<tr>
<td valign="top" width="50%">

**Browsers**
- Red Team Firefox — Burp proxy enforced, FoxyProxy pre-configured, HackTools, Wappalyzer, Retire.js
- OSINT Firefox — VPN-enforced, NoScript, CanvasBlocker, UA Switcher, fingerprint evasion
- Puppet Master Firefox — VPN-enforced, Multi-Account Containers, Temporary Containers, persona tooling
- Unsafe Browser — clearnet fallback, uBlock only, for captive portals

**Proxy enforcement**
- Browsers block all traffic if their assigned proxy is not running
- Burp CA generated on first install — Firefox trusts it immediately, one-time import into Burp
- All proxy settings overridable per-machine via `user/` without touching shared config

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
- Hyper-V Enhanced Session over vsock
- ZSH + tmux, fzf history, syntax highlighting

</td>
</tr>
</table>

---

## Browser profiles

Every profile launches isolated — separate cookies, cache, extensions, and proxy rules. Click the desktop launcher. Nothing bleeds between them.

```
┌─────────────────────────────────────────────────────────────────┐
│  Firefox - Red Team          → Burp Suite  127.0.0.1:8080       │
│  Firefox - OSINT             → VPN SOCKS5  127.0.0.1:1080       │
│  Firefox - Puppet Master     → VPN SOCKS5  127.0.0.1:1080       │
│  Firefox - Unsafe Browser    → Direct (clearnet, no proxy)      │
└─────────────────────────────────────────────────────────────────┘
  If the assigned proxy is not running, the browser blocks. No fallback. No leaks.
```

---

## Quick start

```bash
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/
git -C ~/.dotfiles add hardware-configuration.nix -f
sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure
```

After the first build, use `rebuild`, `upgrade`, or `update` from the shell.

Full guide including Hyper-V Enhanced Session setup → [docs/installation.md](docs/installation.md)

---

## Documentation

| | |
|---|---|
| [Installation](docs/installation.md) | Prerequisites, deploy steps, Hyper-V setup, repo structure |
| [Usage](docs/usage.md) | Browser profiles, Burp + VPN setup, proxy override examples |
| [Customization](docs/customization.md) | User override system, adding tools, dev environment |
| [Roadmap](docs/roadmap.md) | Phase-by-phase progress, planned features |

---

## Status

Active development. Functional and deployable today.

`✔` NixOS flake · Home Manager · plasma-manager  
`✔` KDE Plasma 6 · Krohnkite tiling · Breeze Dark  
`✔` Hyper-V Enhanced Session (vsock)  
`✔` Four Firefox profiles with proxy enforcement and Burp CA automation  
`✔` Offensive, OSINT, and SDR tooling declared in a single module  
`✔` ZSH + tmux environment  
`✔` User override system  

`○` TUI installer · Full disk encryption · ISO build pipeline · Kernel hardening

See [docs/roadmap.md](docs/roadmap.md) for the full picture.

---

<div align="center">

**For authorized security testing, research, and educational use only.**  
Obtain explicit written permission before any assessment. The authors assume no liability for misuse.

</div>
