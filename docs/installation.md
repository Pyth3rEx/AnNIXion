# Installation

## Prerequisites

- A **NixOS installation** with flakes enabled
- Git

Enable flakes if not already:

```nix
# /etc/nixos/configuration.nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

---

## Install

```bash
# Clone to your home directory
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cd ~/.dotfiles

# Copy your hardware configuration
cp /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix

# Track it (required for flakes, but don't push it)
git add ./hardware-configuration.nix -f

# Update flake inputs
nix flake update

# Apply — system + user config in one command
sudo nixos-rebuild switch --flake .#AnNIXion --impure
```

After the first successful build, three shell aliases are available:

| Alias | What it does |
|---|---|
| `rebuild` | Apply current config — same package versions |
| `upgrade` | Update all flake inputs then rebuild |
| `update` | Update flake inputs only, no rebuild |

---

## Repository structure

```
.
├── flake.nix                      # Flake inputs, outputs, system config wiring
├── hardware-configuration.nix     # Auto-generated per-machine — do not edit
│
├── home.nix                       # Base user environment
├── home/
│   ├── firefox/
│   │   ├── default.nix            # Firefox enable, policies, desktop launchers
│   │   ├── untrusted.nix          # Unsafe Browser profile (clearnet, id 0)
│   │   ├── redteam.nix            # Red Team profile: Burp proxy, FoxyProxy, HackTools
│   │   ├── osint.nix              # OSINT profile: VPN-enforced, investigation extensions
│   │   ├── puppet.nix             # Puppet Master: VPN-enforced, persona & container mgmt
│   │   ├── theme.nix              # Per-profile Nord CSS and toolbar layouts
│   │   └── burned-land.nix        # Built-in session-wipe extension
│   ├── vscodium.nix               # VSCodium with Nix IDE, formatters, language server
│   ├── only-office.nix            # OnlyOffice document editor
│   ├── apps-menu.nix              # Kill-chain XDG application menu and desktop entries
│   └── control-center.nix         # Meta key handler and AnNIXion control center
│
├── modules/
│   ├── desktop.nix                # KDE Plasma 6 (X11), SDDM, Krohnkite tiling
│   ├── xrdp.nix                   # Hyper-V Enhanced Session via vsock
│   └── security-tools.nix         # Offensive, OSINT, and SDR packages
│
├── user/                          # Personal overrides — never committed upstream
│   ├── configuration.nix
│   ├── home.nix
│   └── examples/
│       ├── git.nix
│       ├── zsh.nix
│       └── hackthebox.nix
│
└── docs/                          # Extended documentation
```

---

## Hyper-V Enhanced Session

If deploying on Hyper-V, run this on the Windows host then fully shut down and reconnect:

```powershell
Set-VM -VMName "AnNIXion" -EnhancedSessionTransportType HvSocket
Set-VMHost -EnableEnhancedSessionMode $true
```

Full clipboard, audio, and dynamic resolution will be available after reconnecting from Hyper-V Manager.
