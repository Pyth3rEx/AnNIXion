# AnNIXion

> A reproducible, privacy-first offensive security Linux distribution built on NixOS — designed for red teamers and OSINT practitioners who need discretion as much as capability.

---

## What is AnNIXion?

AnNIXion is a NixOS-based security distro that takes the best ideas from Kali Linux and applies them through the lens of the Nix ecosystem: fully declarative, reproducible from source, and composable by design.

It ships two distinct operational modes baked into the desktop from day one:

- **Red Team** — penetration testing, exploitation, network analysis, proxy interception
- **OSINT** — open-source intelligence gathering with a heavy focus on privacy, account compartmentalization, and fingerprint evasion

Both modes coexist on the same install. You choose what you load.

---

## Why NixOS?

| Property | Benefit |
|---|---|
| Declarative config | Your entire OS is a set of text files you can version, share, and reproduce exactly |
| Reproducible builds | Build the same ISO from the same flake and get the same result every time |
| Rollbacks | Every system change is reversible — break something, boot the previous generation |
| Composable modules | Add or remove entire tool layers (OSINT, RedTeam, Privacy) without conflicts |
| Flake-based | Pinned dependencies, no surprise updates, auditable lock file |

---

## Key Features

### Installer
- Custom TUI installer built with `whiptail` — no GUI required
- Full disk encryption via LUKS2 (configured with `disko`)
- Random Windows-style hostname pre-generated at install time (e.g. `DESKTOP-K4MXR2J`) — changeable on prompt
- Profile selection: install RedTeam tools, OSINT tools, or both
- Configurable username, password, timezone

### Firefox — Two Profiles, Two Identities

**RedTeam profile**
- HTTP proxy pre-configured for Burp Suite (127.0.0.1:8080)
- DevTools enabled and accessible
- Extensions: FoxyProxy, Wappalyzer, HackTools
- Minimal fingerprint hardening — speed and functionality over discretion

**OSINT profile**
- Hardened against fingerprinting: Canvas Blocker, ResistFingerprinting flags enabled
- Multi-Account Containers for identity compartmentalization
- Extensions: uBlock Origin, Cookie AutoDelete, User-Agent Switcher, Temporary Containers
- SOCKS5/VPN-aware proxy settings
- JavaScript toggleable per-container

### Tool Layers
- **RedTeam**: nmap, metasploit, burpsuite, sqlmap, gobuster, evil-winrm, impacket, crackmapexec, and more
- **OSINT**: theHarvester, maltego, spiderfoot, sherlock, holehe, recon-ng, ExifTool, and more
- **Privacy**: Tor, Proxychains-ng, VPN clients (Mullvad, ProtonVPN), MAC address randomization

### System Hardening
- Kernel hardening parameters enabled by default
- MAC address randomization on network interfaces
- Minimal attack surface — no unnecessary services running

---

## Installing


```bash
sudo nixos-rebuild switch --flake git+ssh://git@github.com/Pyth3rEx/AnNIXion#nixos
```

---

## Development Setup

To contribute or build locally, you need a NixOS system (or VM) with flakes enabled:

```nix
# In your NixOS configuration.nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Then clone the repo and iterate. Test ISOs in a nested VM — no need to install on bare metal during development.

---

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

> AnNIXion is intended for authorized security testing, research, and educational use only.
> Always ensure you have explicit permission before conducting any security assessment.
