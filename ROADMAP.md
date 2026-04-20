# AnNIXion Roadmap

Development is organized in phases. Each phase produces a working, testable artifact before the next begins.

---

## Phase 1 — Flake Scaffold and ISO Build Target

Goal: a flake that builds a bootable ISO with nothing but a shell on it.

- [ ] `flake.nix` with inputs: `nixpkgs`, `home-manager`, `disko`
- [ ] `modules/base/system.nix` — locale, timezone stub, basic kernel params
- [ ] `modules/iso.nix` — imports the NixOS cd-dvd installer module, boots to shell
- [ ] ISO builds with `nix build .#nixosConfigurations.annixion-iso.config.system.build.isoImage`

---

## Phase 2 — Disk Layout and Full Disk Encryption

Goal: the ISO can partition a disk, set up LUKS2 encryption, and install NixOS.

- [ ] `disko/luks-btrfs.nix` — declarative partition layout: EFI, LUKS2-encrypted root, btrfs subvolumes
- [ ] `disko` flake input wired into `flake.nix`
- [ ] Tested in a VM: full install with encryption passphrase, boots successfully, decrypts on boot

---

## Phase 3 — TUI Installer

Goal: running `annixion-install` from the live ISO walks through the full setup interactively.

- [ ] `installer/annixion-install.sh` — whiptail-based TUI
- [ ] Prompts: disk selection, encryption passphrase, hostname (pre-filled random Windows-style), username, password, timezone, profile selection
- [ ] Hostname generator: `DESKTOP-XXXXXXX` / `LAPTOP-XXXXXXX` format
- [ ] Profile selection writes feature flags into the generated config
- [ ] Calls `disko` for partitioning then `nixos-install --flake` to finalize
- [ ] Script available in the live environment as `annixion-install`

---

## Phase 4 — Base System and User Management

Goal: a clean, minimal installed system that boots to a desktop.

- [ ] `modules/base/system.nix` — finalized: kernel hardening flags, MAC address randomization, no unnecessary services
- [ ] `modules/base/users.nix` — default non-root user, sudo via wheel group
- [ ] `home/default.nix` — Home Manager wired in, basic shell config (zsh or fish)
- [ ] System boots, user can log in, flake is available for rebuilds

---

## Phase 5 — Desktop Environment

Goal: a functional, minimal desktop that doesn't scream "hacker distro" from across the room.

- [ ] `modules/desktop/default.nix` — choose and configure DE/WM (decision pending)
- [ ] Theming: clean, neutral appearance by default
- [ ] Terminal emulator, file manager, basic tooling in place

---

## Phase 6 — Firefox Profiles

Goal: Firefox ships with two pre-configured profiles selectable from launch.

- [ ] `modules/desktop/firefox.nix` — Firefox installed via Home Manager with policy config
- [ ] `home/firefox/redteam-profile.nix`:
  - HTTP proxy set to 127.0.0.1:8080 (Burp)
  - DevTools enabled
  - Extensions: FoxyProxy, Wappalyzer, HackTools
- [ ] `home/firefox/osint-profile.nix`:
  - ResistFingerprinting and related about:config flags
  - Multi-Account Containers, Temporary Containers
  - Extensions: uBlock Origin, Cookie AutoDelete, User-Agent Switcher
  - SOCKS5 proxy config
- [ ] Profile switcher or launcher shortcuts on the desktop

---

## Phase 7 — Tool Layers

Goal: RedTeam and OSINT tool sets installable as modules, selectable at install time.

- [ ] `modules/tools/redteam.nix` — nmap, metasploit, burpsuite, sqlmap, gobuster, evil-winrm, impacket, crackmapexec, netcat, wireshark, john, hashcat
- [ ] `modules/tools/osint.nix` — theHarvester, spiderfoot, sherlock, holehe, recon-ng, maltego, ExifTool, metagoofil, photon
- [ ] `modules/tools/privacy.nix` — tor, torbrowser, proxychains-ng, mullvad-vpn, protonvpn, macchanger
- [ ] Profile flag from Phase 3 installer controls which modules are included

---

## Phase 8 — Overlays and Missing Packages

Goal: tools not in nixpkgs are packaged and available.

- [ ] `overlays/default.nix` wired into flake
- [ ] Audit Phase 7 tool lists — identify any tools missing from nixpkgs
- [ ] Write derivations for missing tools or point to community flakes (e.g. `nix-security-box`)

---

## Phase 9 — Hardening and Privacy Defaults

Goal: system-level privacy and hardening that goes beyond just tool selection.

- [ ] Kernel: `kernel.dmesg_restrict`, `kernel.kptr_restrict`, sysctl hardening set
- [ ] Network: MAC randomization on all interfaces at boot, firewall defaults
- [ ] systemd: minimal services, no avahi, no cups unless opted in
- [ ] Audit: check what the system phones home by default and silence it

---

## Phase 10 — Polish and Documentation

Goal: someone who has never used NixOS can follow the README and get a working install.

- [ ] ISO tested on real hardware (at least one machine)
- [ ] README install instructions verified end-to-end
- [ ] CONTRIBUTING.md for people who want to add tools or profiles
- [ ] Versioned releases with tagged ISOs

---

## Deferred / Future Ideas

- Calamares GUI installer as an alternative to the TUI installer
- ARM64 / Raspberry Pi image target
- Mullvad kill-switch integration at the NixOS firewall level
- Auto-updating tool definitions via flake inputs
- i3/Hyprland layout presets for RedTeam vs OSINT workspaces
- Dedicated OSINT VM image (lighter, browser-forward, no pentest tools)
