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

Or use [Rufus](https://rufus.ie) on Windows.

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
6. Clone the AnNIXion config to `~/.dotfiles` (its canonical location — the
   config references `~/.dotfiles/assets/…` for the wallpaper, icons and certs)
7. Generate and stage `hardware-configuration.nix` for your machine
8. Run `nixos-install --flake ~/.dotfiles#AnNIXion` and hand the dotfiles to the
   `operator` user
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

See [docs/zsh.md](zsh.md) for a full reference of shell shortcuts and aliases.

---

## Repository structure

```
.
├── flake.nix                      # Inputs, outputs, system and user wiring
├── iso.nix                        # Live installer ISO configuration
├── hardware-configuration.nix     # Auto-generated per-machine — gitignored, do not edit
├── VERSION                        # Semantic version — bumped on every release
├── RELEASE_NAME                   # Codename for the current release
│
├── scripts/
│   └── annixion-install           # Guided installer, bundled into the ISO
│
├── home.nix                       # Base user environment
├── home/
│   ├── firefox/
│   │   ├── default.nix            # Firefox enable, policies, desktop launchers
│   │   ├── untrusted.nix          # Unsafe Browser profile (clearnet, id 0)
│   │   ├── redteam.nix            # Red Team profile: Burp proxy, web tooling
│   │   ├── osint.nix              # OSINT profile: VPN-enforced, investigation extensions
│   │   ├── puppet.nix             # Puppet Master: VPN-enforced, persona and containers
│   │   └── theme.nix              # Per-profile Nord CSS and toolbar layouts
│   ├── plasma.nix                 # KDE Plasma: panels, shortcuts, Krohnkite tiling
│   ├── zsh/
│   │   ├── default.nix            # ZSH: oh-my-zsh, aliases, plugins, banner
│   │   ├── oh-my-posh.nix         # Prompt: enabled for zsh and bash
│   │   └── omp-theme.nix          # Prompt: blocks, segments, colours
│   ├── fastfetch.nix              # Fastfetch system-info banner
│   ├── vscodium.nix               # VSCodium with the Nix toolchain
│   ├── only-office.nix            # OnlyOffice document editor
│   ├── apps-menu.nix              # Kill-chain application menu and desktop entries
│   ├── control-center.nix         # annixion-cc control center, Meta key handler
│   └── file-visibility.nix        # Show hidden files across KDE, GTK, rg and fd
│
├── modules/
│   ├── desktop.nix                # Plasma 6 on X11, SDDM, KDE extras
│   ├── xrdp.nix                   # Hyper-V guest support, Enhanced Session via vsock
│   ├── security-tools.nix         # Offensive, OSINT, RF and forensics packages
│   ├── vpn-enforcement.nix        # Kernel killswitch: egress confined to the VPN
│   ├── hardening.nix              # Attack surface reduction
│   └── shell.nix                  # Zsh for every login, prompt for shells HM does not own
│
├── tests/
│   ├── boot.nix                   # VM test: system boots, services start
│   ├── security-tools.nix         # VM test: all tools are present
│   └── vpn-enforcement.nix        # VM test: killswitch loads and fails closed
│
├── ci/
│   └── hardware-stub.nix          # Stand-in disk layout for CI and fresh clones
│
├── assets/                        # Wallpapers, icons, bookmarks, Burp CA
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

### Audio

Hyper-V emulates no sound card, so the guest has no audio hardware to speak of.
Sound reaches the Windows host over xrdp's redirection channel instead, which
`modules/xrdp.nix` enables with `services.xrdp.audio.enable`.

That channel only works over PulseAudio: xrdp redirects through
`module-xrdp-sink` and `module-xrdp-source`, native modules of the PulseAudio
daemon. `pipewire-pulse` reimplements the PulseAudio protocol but cannot load
them, and no PipeWire equivalent is packaged. The Hyper-V profile therefore
turns PipeWire off and runs PulseAudio, overriding the flake default. Nothing
is lost by it — with no sound card present, PipeWire has no device to manage.

Audio appears only inside an Enhanced Session. A plain RDP or console login has
no redirection channel, so the guest shows no audio device there.
