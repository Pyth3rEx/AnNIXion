# Installation

Two paths depending on your starting point.

---

## Option A — Fresh install from ISO (recommended)

No prior NixOS required. Boot the live ISO and run the guided installer.

### 1. Download the ISO

Grab the latest `AnNIXion-vX.Y.Z.iso` from the [Releases](https://github.com/Pyth3rEx/AnNIXion/releases) page.

### 2. Flash to USB

```bash
# Linux / macOS
sudo dd if=AnNIXion-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Or use [Balena Etcher](https://etcher.balena.io) on Windows.

### 3. Boot

Boot the USB. The system auto-logs in as `operator` and drops you at a shell.

### 4. Connect to the internet

```bash
nmtui    # text UI for NetworkManager — connect to WiFi or configure ethernet
```

### 5. Install

```bash
annixion-install
```

The script will:

1. List available disks
2. Ask which disk to install on
3. Ask for confirmation before wiping
4. Partition GPT: 512 MiB ESP + remaining root
5. Format ESP as FAT32, root as ext4
6. Clone the AnNIXion config to `/mnt/etc/nixos`
7. Generate `hardware-configuration.nix` for your machine
8. Run `nixos-install --flake /mnt/etc/nixos#AnNIXion`
9. Offer to reboot

> **Note:** Security tools (Metasploit, Ghidra, etc.) are large. Expect 30–60 min on a slow connection.

---

## Option B — Install on existing NixOS

If you already have NixOS with flakes enabled:

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

Enable flakes first if not already:

```nix
# /etc/nixos/configuration.nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
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
├── iso.nix                        # Minimal installer ISO configuration
├── hardware-configuration.nix     # Auto-generated per-machine — do not edit
├── VERSION                        # Semantic version — bumped on every PR to main
│
├── scripts/
│   └── annixion-install           # Guided bash installer (bundled into the ISO)
│
├── home.nix                       # Base user environment
├── home/
│   ├── firefox/
│   │   ├── default.nix            # Firefox enable, policies, desktop launchers
│   │   ├── untrusted.nix          # Unsafe Browser profile (clearnet, id 0)
│   │   ├── redteam.nix            # Red Team profile: Burp proxy, FoxyProxy, HackTools
│   │   ├── osint.nix              # OSINT profile: VPN-enforced, investigation extensions
│   │   ├── puppet.nix             # Puppet Master: VPN-enforced, persona & container mgmt
│   │   └── theme.nix              # Per-profile Nord CSS and toolbar layouts
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
├── tests/
│   ├── boot.nix                   # VM test: system boots, services start
│   └── security-tools.nix         # VM test: all tools are present
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
