# AnNIXion Roadmap

Development is organized in phases. Each phase produces a working, testable artifact before the next begins.

---

## Phase 1 — Flake Scaffold and ISO Build Target

Goal: a flake that builds a bootable ISO with nothing but a shell on it.

- [x] `flake.nix` with inputs: `nixpkgs`, `home-manager`, `plasma-manager`
- [x] `configuration.nix` — locale, timezone, basic kernel params
- [ ] `modules/base/system.nix` — extract system config into proper module structure
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

## Phase 4 — Base System and User Environment

Goal: a clean, minimal installed system that boots to a working desktop.

- [x] Default non-root user (`operator`), sudo via wheel group
- [x] Home Manager wired into flake — single `nixos-rebuild switch` handles system + user config
- [x] ZSH with autosuggestions, syntax highlighting, fzf history search
- [x] tmux, xterm terminal, git declared via Home Manager
- [x] `nix.gc` — automatic weekly cleanup of old generations
- [x] `modules/` — flat module structure: desktop, xrdp, shell, security-tools
- [ ] `modules/base/users.nix` — user management as a standalone module

---

## Phase 5 — Desktop Environment

Goal: a functional desktop accessible to both technical and non-technical operators.

**Decision: KDE Plasma 6 on X11**

Rationale:
- Broadest audience compatibility — familiar paradigm for operators coming from Windows
- Full keyboard-driven workflow available via KRunner and Krohnkite tiling
- Stable X11 session required for reliable xrdp/Enhanced Session support
- Wayland (Plasma 6) available as a future upgrade path once xrdp Wayland support matures

- [x] KDE Plasma 6 declared in `modules/desktop.nix`
- [x] SDDM login manager
- [x] Krohnkite tiling script enabled (i3-style auto-tiling within Plasma)
- [x] KDE shortcuts declared via `plasma-manager` in `home.nix` — Meta+1-4 desktops, Meta+Return terminal, Meta+Q close
- [x] Breeze Dark theme set as default
- [x] 4 virtual desktops configured
- [ ] Theming pass — neutral professional appearance, not default KDE blue
- [ ] Application launcher and taskbar layout declared in Nix
- [ ] Wallpaper and visual identity pass

---

## Phase 5a — Hyper-V Enhanced Session Support

Goal: full Enhanced Session (clipboard, audio, dynamic resolution, USB redirection) over vsock.

- [x] `virtualisation.hypervGuest.enable = true`
- [x] `boot.blacklistedKernelModules = [ "hyperv_fb" ]` — forces `hyperv_drm`
- [x] `boot.kernelModules = [ "hv_sock" ]` — vsock transport loaded at boot
- [x] xrdp `ExecStart` overridden to `vsock://-1:3389` via `lib.mkForce` in `modules/xrdp.nix`
- [x] `vmconnect=true` patched into xrdp.ini via `preStart` hook
- [x] KDE Plasma X11 session launches correctly over Enhanced Session
- [ ] Performance tuning — compositor settings, RDP color depth, animation speed
- [ ] Multi-monitor configuration declared in Nix
- [ ] Audio passthrough verified end-to-end

---

## Phase 6 — User Overlay System ✓

Goal: users can drop personal dotfiles into a `user/` folder that survives reinstalls and never gets committed to the main repo.

- [x] `user/` directory with stub files tracked in the repo
- [x] `user/home.nix` — optional user override, merged into base `home.nix` at build time via `imports`
- [x] `user/configuration.nix` — optional system override, conditionally imported via `builtins.pathExists`
- [x] All base options use `lib.mkDefault` (priority 1000) so user overrides win at normal priority — no `lib.mkForce` needed
- [x] `user/examples/git.nix` — ready-to-use git identity and signing override
- [x] `user/examples/zsh.nix` — recon aliases and banner override example
- [x] `user/README.md` — explains what can be overridden and how, with examples

---

## Phase 7 — Firefox Profiles ✓

Goal: Firefox ships with two pre-configured profiles selectable from launch.

> **Implemented.** Structure differs slightly from original plan — everything lives under `home/firefox/` rather than splitting between `modules/desktop/` and `home/firefox/`.

- [x] `home/firefox/default.nix` — Firefox enable, force-installed policies, desktop launchers
- [x] `home/firefox/redteam.nix` — Red Team profile: FoxyProxy, HackTools, Wappalyzer, Cookie Editor, Retire.js; search engines: Exploit-DB, CVE, NVD
- [x] `home/firefox/osint.nix` — OSINT profile: NoScript, Multi-Account Containers, CanvasBlocker, User-Agent Switcher, Cookie AutoDelete; search engines: Shodan, Censys, Wayback Machine
- [x] Desktop launchers for each profile via `xdg.desktopEntries`
- [ ] HTTP proxy pre-configured (127.0.0.1:8080) in redteam profile settings
- [ ] ResistFingerprinting flags wired in osint profile settings
- [ ] Per-profile theming (ShyFox — black/red for RedTeam, yellow for OSINT)

---

## Phase 8 — Tool Layers

Goal: RedTeam and OSINT tool sets installable as modules, selectable at install time.

> **Partial progress:** `modules/security-tools.nix` currently ships all offensive, OSINT, and SDR tools as a single flat module. Phase 8 splits this into separate, independently selectable profiles.

- [ ] `modules/tools/redteam.nix` — nmap, metasploit, burpsuite, sqlmap, gobuster, evil-winrm, impacket, crackmapexec, netcat, wireshark, john, hashcat, hydra, aircrack-ng, ghidra, binwalk
- [ ] `modules/tools/osint.nix` — theHarvester, spiderfoot, sherlock, holehe, recon-ng, maltego, ExifTool, metagoofil, photon
- [ ] `modules/tools/privacy.nix` — tor, torbrowser, proxychains-ng, mullvad-vpn, protonvpn, macchanger
- [ ] `modules/tools/sdr.nix` — hackrf, gqrx, gnuradio (RF/SDR toolchain)
- [ ] Split `modules/security-tools.nix` into the above and remove it
- [ ] Profile flag from Phase 3 installer controls which modules are included

---

## Phase 9 — Overlays and Missing Packages

Goal: tools not in nixpkgs are packaged and available.

- [ ] `overlays/default.nix` wired into flake
- [ ] Audit Phase 8 tool lists — identify any tools missing from nixpkgs
- [ ] Write derivations for missing tools or point to community flakes

---

## Phase 10 — Hardening and Privacy Defaults

Goal: system-level privacy and hardening that goes beyond tool selection.

- [ ] Kernel: `kernel.dmesg_restrict`, `kernel.kptr_restrict`, full sysctl hardening set
- [ ] Network: MAC randomization on all interfaces at boot, firewall defaults
- [ ] systemd: minimal services, no avahi, no cups unless opted in
- [ ] Audit: verify what the system contacts by default and silence unnecessary traffic

---

## Phase 11 — Polish and Documentation

Goal: someone who has never used NixOS can follow the README and get a working install.

- [ ] ISO tested on real hardware (at least one machine)
- [ ] README install instructions verified end-to-end
- [ ] CONTRIBUTING.md for people who want to add tools or profiles
- [ ] Versioned releases with tagged ISOs

---

## Deferred / Future Ideas

- Wayland session support once xrdp Wayland backend matures
- Hyprland as an optional power-user layer (declared via Home Manager, opt-in)
- Calamares GUI installer as an alternative to the TUI installer
- ARM64 / Raspberry Pi image target
- Mullvad kill-switch integration at the NixOS firewall level
- Auto-updating tool definitions via flake inputs
- Dedicated OSINT VM image — lighter, browser-forward, no pentest tools
