# AnNIXion

![AnNIXion banner](banner.png)

> A declarative, reproducible offensive security distribution built on NixOS — for operators who treat their environment as infrastructure.

---

## Overview

AnNIXion is a NixOS-based security distribution designed for three audiences:

- **Red teamers** — penetration testing, exploitation, network analysis, proxy interception
- **OSINT & intelligence practitioners** — source gathering, identity compartmentalization, fingerprint evasion
- **Persona operators** — sock puppet management, avatar lifecycle, cover maintenance, social platform presence

The entire system — tools, desktop, configuration, user environment — is declared in code. No manual setup. No configuration drift. No "works on my machine."

---

## Why AnNIXion

Most security distributions are curated package lists on top of a general-purpose OS. You get the tools, but not the environment. Configuration drifts. Reinstalls diverge. What ran on your last machine may not run on this one.

AnNIXion is different in kind, not just degree. The name comes from *annexion* — to take full control of a territory, absorb it completely, make it yours. That is the operating principle.

| Property | What it means in practice |
|---|---|
| **Your environment is code** | The entire system — tools, desktop, shell, shortcuts — lives in text files you own and version |
| **No drift** | Two operators deploying the same config get the same machine. No exceptions. |
| **Reversible by default** | Every change is a new generation. Break something, boot the previous state in seconds. |
| **Composable layers** | RedTeam, OSINT, and Privacy tooling are separate modules. Load what the operation requires. |
| **Auditable supply chain** | Pinned dependencies, lockfile-tracked. You know exactly what is running and where it came from. |

You do not configure AnNIXion. You declare it — and it becomes exactly what you declared.

---

## Current State

AnNIXion is in **active development**. The following is implemented and functional:

- ✅ NixOS flake with Home Manager and plasma-manager integration
- ✅ Modular config structure — desktop, xrdp, shell, and security tools each in their own module
- ✅ KDE Plasma 6 desktop (X11) with Krohnkite tiling and Breeze Dark theme
- ✅ Hyper-V Enhanced Session over vsock (xrdp)
- ✅ Offensive, OSINT, and SDR tooling declared in `modules/security-tools.nix`
- ✅ ZSH + tmux + xterm terminal environment
- ✅ User override system — drop personal settings into `user/` without touching base config
- ✅ Firefox four-profile setup — Unsafe Browser, RedTeam (Burp proxy enforced), OSINT, and Puppet Master profiles with dedicated extensions, search engines, and desktop launchers
- ✅ VS Code development environment module with Nix IDE extension

The following is planned and tracked in [ROADMAP.md](ROADMAP.md):

- TUI installer with profile selection
- Full tool layer separation (RedTeam, OSINT, Privacy) as independently selectable modules
- Kernel hardening and system-level privacy defaults
- ISO build pipeline with automated releases

---

## Quick Start

### Prerequisites

- A **NixOS installation** with flakes enabled
- Git

### Installation

> ⚠️ **Note:** Automated installer is under development. For now, manual setup is required.

**1. Enable flakes** (if not already enabled):

```nix
# /etc/nixos/configuration.nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

**2. Clone and deploy:**

```bash
# Clone the repository to your home directory
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cd ~/.dotfiles

# Copy your hardware configuration
cp /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix

# Track it in git (required for flakes, but don't commit it upstream)
git add ./hardware-configuration.nix -f

# Update flake inputs to latest versions
nix flake update

# Apply the complete configuration (system + user, one command)
sudo nixos-rebuild switch --flake .#AnNIXion --impure
```

**3. Shell aliases:**

After the initial install succeeds, three aliases are available:

```bash
rebuild   # Apply current config — same package versions, no input updates
upgrade   # Update all flake inputs (nixpkgs, packages) then rebuild
update    # Update flake inputs only, without rebuilding
```

### Hyper-V Enhanced Session Setup

If deploying on Hyper-V, enable Enhanced Session support on the Windows host:

```powershell
# Run on the Windows host
Set-VM -VMName "AnNIXion" -EnhancedSessionTransportType HvSocket
Set-VMHost -EnableEnhancedSessionMode $true
```

Then fully shut down the VM and reconnect from Hyper-V Manager. The desktop will now run over Enhanced Session with full clipboard, audio, and dynamic resolution support.

---

## Repository Structure

```
.
├── flake.nix                      # Flake inputs, outputs, system config wiring
├── flake.lock                     # Locked dependency versions (commit this)
├── hardware-configuration.nix     # Auto-generated per-machine — do not edit manually
│
├── home.nix                       # Base user environment: shell, dev tools, KDE, Firefox
├── home/
│   └── firefox/
│       ├── default.nix            # Firefox enable, policies, desktop launchers
│       ├── untrusted.nix          # Unsafe Browser profile: direct connection, uBlock only
│       ├── redteam.nix            # Red Team profile: FoxyProxy → Burp, HackTools, Wappalyzer
│       ├── osint.nix              # OSINT profile: VPN-enforced, extensions for investigations
│       └── puppet.nix             # Puppet Master profile: VPN-enforced, persona & container mgmt
│
├── modules/
│   ├── desktop.nix                # KDE Plasma 6 (X11), SDDM, Krohnkite tiling
│   ├── xrdp.nix                   # Hyper-V Enhanced Session via vsock
│   ├── security-tools.nix         # Offensive, OSINT, and SDR packages
│   └── vscode.nix                 # VS Code with Nix IDE and dev dependencies
│
└── user/                          # Your personal overrides — never committed
    ├── configuration.nix          # System-level overrides
    ├── home.nix                   # User-environment overrides
    ├── examples/
    │   ├── git.nix                # Example: git identity and signing config
    │   └── zsh.nix                # Example: welcome banner and aliases
    └── README.md                  # How the override system works
```

---

## Customization

### User Overrides

All base config options use `lib.mkDefault`, meaning your settings in `user/` automatically take precedence. No `lib.mkForce` needed.

**Get started immediately:**

1. **Set your git identity** — uncomment the git example in `user/home.nix`:
   ```nix
   imports = [ ./examples/git.nix ];
   ```

2. **Add a welcome banner** — uncomment the zsh example:
   ```nix
   imports = [ ./examples/zsh.nix ];
   ```

3. **Apply changes:**
   ```bash
   rebuild
   ```

See `user/README.md` for the full override system documentation.

### Firefox Profiles

Four Firefox profiles launch from the desktop:

- **Unsafe Browser** — Direct connection, no proxy, uBlock only. Use for captive portals or clearnet sessions. Bare `firefox` with no `-P` flag opens this profile.
- **Red Team** — FoxyProxy pre-configured to route all traffic through Burp Suite (127.0.0.1:8080). Falls back to blocked (no direct leak) if Burp is not running.
- **OSINT** — All traffic enforced through VPN (SOCKS5 at 127.0.0.1:1080). NoScript, CanvasBlocker, User-Agent Switcher; search engines for Shodan, Censys, Wayback Machine.
- **Puppet Master** — All traffic enforced through VPN (SOCKS5 at 127.0.0.1:1080). Multi-Account Containers, Temporary Containers; search engines for Yandex, Baidu, social platforms.

Each profile has its own isolated cookies, cache, and extensions. Click the desktop launcher for the profile you need.

---

## Development Setup

### Nix IDE for VS Code

A complete VS Code module with Nix language support is included:

- **Language Server:** `nil` with intelligent code completion and diagnostics
- **Formatting:** Auto-format on save with proper 2-space indentation
- **Linting:** Real-time error detection with `statix` and `deadnix`
- **Extensions:** GitLens, YAML, TOML support included

To enable in your `user/home.nix`:

```nix
imports = [ ../modules/vscode.nix ];
```

Then rebuild and open VS Code.

---

## Planned Features

See [ROADMAP.md](ROADMAP.md) for the complete development roadmap, organized by phase.

**Upcoming highlights:**

- **Phase 3:** Interactive TUI installer with profile selection
- **Phase 8:** Separate, independently-selectable tool modules (RedTeam, OSINT, Privacy, SDR)
- **Phase 10:** System-level hardening, kernel parameters, MAC randomization
- **Phase 11:** ISO releases, installation verification, contribution guidelines

---

## Support & Contribution

- **Issues:** Report bugs or request features on GitHub
- **Contributing:** Guidelines coming in Phase 11
- **Documentation:** See `user/README.md` for customization and overrides

---

## Legal & Disclaimer

> **For authorized security testing, research, and educational use only.**
>
> AnNIXion is a tool. Like any tool, it can be misused. You are responsible for:
> - Obtaining explicit written permission before conducting any security assessment
> - Understanding and complying with all applicable laws and regulations in your jurisdiction
> - Using this distribution ethically and responsibly
>
> The authors assume no liability for misuse.
