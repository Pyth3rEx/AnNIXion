# AnNIXion

![AnNIXion banner](banner.png)

> A declarative, reproducible offensive security distribution built on NixOS — for operators who treat their environment as infrastructure.

[**Installation**](docs/installation.md) · [**Usage**](docs/usage.md) · [**Customization**](docs/customization.md) · [**Roadmap**](docs/roadmap.md)

---

## What it is

AnNIXion is a NixOS-based security distribution for red teamers, OSINT practitioners, and persona operators. The entire system — tools, browsers, shell, desktop — is declared in code and reproduced exactly from a single flake.

The name comes from *annexion* — to take full control of a territory, absorb it completely, make it yours.

---

## Features

| | |
|---|---|
| **Four isolated Firefox profiles** | Red Team (Burp enforced), OSINT (VPN enforced), Puppet Master (VPN enforced), Unsafe Browser (clearnet fallback) |
| **Proxy kill-switch** | Browsers block all traffic if their proxy is not running. No leaks. |
| **Burp CA auto-generated** | CA cert created on first install. Firefox trusts it immediately. One-time import into Burp and it works. |
| **Offensive tooling** | Metasploit, Burp Suite, nmap, Ghidra, SQLMap, Hydra, aircrack-ng, Volatility, Autopsy — declared in one module |
| **OSINT & SDR tooling** | theHarvester, HackRF, GNURadio, GQRX — ready on first boot |
| **Reproducible builds** | Pinned flake inputs. Same config, same machine, every time. |
| **User override system** | Personal settings in `user/` win over base config via `lib.mkDefault` — no force needed |

---

## Quick start

```bash
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/
git -C ~/.dotfiles add hardware-configuration.nix -f
sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure
```

Full prerequisites, post-install steps, and Hyper-V setup: [docs/installation.md](docs/installation.md)

---

## Current state

Active development. Functional and deployable on NixOS.

- NixOS flake with Home Manager and plasma-manager
- KDE Plasma 6 (X11) with Krohnkite tiling, Breeze Dark
- Hyper-V Enhanced Session over vsock
- Four Firefox profiles with proxy enforcement and Burp CA automation
- Offensive, OSINT, and SDR tooling in `modules/security-tools.nix`
- ZSH + tmux + xterm environment
- User override system with examples

See [docs/roadmap.md](docs/roadmap.md) for phase-by-phase progress and what's coming next.

---

## Legal

For authorized security testing, research, and educational use only. Obtain explicit written permission before conducting any security assessment and comply with all applicable laws. The authors assume no liability for misuse.
