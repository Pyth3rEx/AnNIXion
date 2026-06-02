# AnNIXion Roadmap

Development is organized in phases. Each phase produces a working, testable artifact before the next begins.

---

## Phase 1 — Flake Scaffold and ISO Build Target ✓

**Goal:** A flake that builds a bootable ISO.

- [x] `flake.nix` with inputs: `nixpkgs`, `home-manager`, `plasma-manager`
- [x] `configuration.nix` — locale, timezone, basic kernel params
- [x] Base system configuration functional
- [ ] `modules/iso.nix` — formal ISO build target, boots to shell
- [ ] ISO builds with `nix build .#nixosConfigurations.annixion-iso.config.system.build.isoImage`

---

## Phase 2 — Disk Layout and Full Disk Encryption

**Goal:** The ISO can partition a disk, set up LUKS2 encryption, and install NixOS.

- [ ] `disko/luks-btrfs.nix` — declarative partition layout: EFI, LUKS2-encrypted root, btrfs subvolumes
- [ ] `disko` flake input wired into `flake.nix`
- [ ] Tested in a VM: full install with encryption passphrase, boots successfully, decrypts on boot

---

## Phase 3 — TUI Installer

**Goal:** Running `annixion-install` from the live ISO walks through the full setup interactively.

- [ ] `installer/annixion-install.sh` — whiptail-based TUI with clean UX
- [ ] Prompts:
  - Disk selection with confirmation
  - Encryption passphrase (confirm entry)
  - Hostname (pre-filled with random Windows-style: `DESKTOP-XXXXXXX`)
  - Username and password
  - Timezone (searchable list)
  - Profile selection (RedTeam, OSINT, Privacy — multi-select)
- [ ] Hostname generator: cryptographically random `DESKTOP-XXXXXXX` / `LAPTOP-XXXXXXX` format
- [ ] Profile selection writes feature flags into the generated flake config
- [ ] Calls `disko` for partitioning then `nixos-install --flake` to finalize
- [ ] Post-install: script available in the live environment as `annixion-install`
- [ ] Error handling: graceful rollback on failed partitioning or install

---

## Phase 4 — Base System and User Environment ✓

**Goal:** A clean, minimal installed system that boots to a working desktop.

- [x] Default non-root user (`operator`), sudo via wheel group
- [x] Home Manager wired into flake — single `nixos-rebuild switch` handles system + user config
- [x] ZSH with autosuggestions, syntax highlighting, fzf history search
- [x] tmux, xterm terminal, git declared via Home Manager
- [x] `nix.gc` — automatic weekly cleanup of old generations
- [x] `modules/` — modular structure: desktop, xrdp, shell, security-tools
- [ ] `modules/base/users.nix` — user management as a standalone module
- [ ] Additional shell environment: `direnv` integration with `.envrc` examples

---

## Phase 5 — Desktop Environment ✓

**Goal:** A functional desktop accessible to both technical and non-technical operators.

**Decision: KDE Plasma 6 on X11**

Rationale:
- Broadest audience compatibility — familiar paradigm for operators coming from Windows
- Full keyboard-driven workflow available via KRunner and Krohnkite tiling
- Stable X11 session required for reliable xrdp/Enhanced Session support
- Wayland (Plasma 6) available as a future upgrade path once xrdp Wayland support matures

- [x] KDE Plasma 6 declared in `modules/desktop.nix`
- [x] SDDM login manager with Breeze theme
- [x] Krohnkite tiling script enabled (i3-style auto-tiling within Plasma)
- [x] KDE shortcuts via `plasma-manager`: Meta+1-4 desktops, Meta+Return terminal, Meta+Q close
- [x] Breeze Dark theme set as default
- [x] 4 virtual desktops preconfigured
- [ ] Theming pass — neutral professional appearance, not default KDE blue
- [ ] Application launcher and taskbar layout declared in Nix
- [ ] Custom wallpaper and visual identity pass

---

## Phase 5a — Hyper-V Enhanced Session Support ✓

**Goal:** Full Enhanced Session (clipboard, audio, dynamic resolution, USB redirection) over vsock.

- [x] `virtualisation.hypervGuest.enable = true`
- [x] `boot.blacklistedKernelModules = [ "hyperv_fb" ]` — forces `hyperv_drm`
- [x] `boot.kernelModules = [ "hv_sock" ]` — vsock transport loaded at boot
- [x] xrdp `ExecStart` overridden to `vsock://-1:3389` via `lib.mkForce` in `modules/xrdp.nix`
- [x] `vmconnect=true` patched into xrdp.ini via `preStart` hook
- [x] KDE Plasma X11 session launches correctly over Enhanced Session
- [x] Tested on Hyper-V with Windows 10 / Windows Server hosts
- [ ] Performance tuning — compositor settings, RDP color depth, animation speed
- [ ] Multi-monitor configuration declared in Nix
- [ ] Audio passthrough verified end-to-end

---

## Phase 6 — User Overlay System ✓

**Goal:** Users can drop personal dotfiles into a `user/` folder that survives reinstalls and never gets committed.

- [x] `user/` directory with stub files tracked in the repo
- [x] `user/home.nix` — optional user override, merged into base `home.nix` via `imports`
- [x] `user/configuration.nix` — optional system override, conditionally imported via `builtins.pathExists`
- [x] All base options use `lib.mkDefault` (priority 1000) so user overrides win at normal priority — no `lib.mkForce` needed
- [x] `user/examples/git.nix` — ready-to-use git identity and signing override
- [x] `user/examples/zsh.nix` — recon aliases and banner override example
- [x] `user/README.md` — explains what can be overridden and how, with examples

---

## Phase 7 — Firefox Profiles ✓

**Goal:** Firefox ships with three pre-configured profiles selectable from launch.

- [x] `home/firefox/default.nix` — Firefox enable, force-installed policies, desktop launchers
- [x] `home/firefox/untrusted.nix` — Unsafe Browser profile (id 0, isDefault): direct connection, uBlock only; replaces empty default profile
- [x] `home/firefox/redteam.nix` — Red Team profile: FoxyProxy, HackTools, Wappalyzer, Cookie Editor, Retire.js; search engines: Exploit-DB, CVE, NVD
- [x] `home/firefox/osint.nix` — OSINT profile: NoScript, CanvasBlocker, User-Agent Switcher, Cookie AutoDelete; search engines: Shodan, Censys, Wayback Machine
- [x] `home/firefox/puppet.nix` — Puppet Master profile: Multi-Account Containers, Temporary Containers, CanvasBlocker, User-Agent Switcher, NoScript; search engines: Yandex, Baidu, social search
- [x] Desktop launchers for each profile via `xdg.desktopEntries`
- [x] FoxyProxy pre-configured via managed storage (`3rdparty` policy) to route all RedTeam traffic through Burp Suite (127.0.0.1:8080); `failover_direct = false` blocks leaks if Burp is down
- [x] VPN enforcement in OSINT and Puppet profiles: SOCKS5 placeholder at 127.0.0.1:1080, DNS through proxy, `failover_direct = false` — connections fail until VPN is running
- [ ] ResistFingerprinting flags wired in OSINT profile settings
- [ ] Per-profile custom `userChrome.css` for immediate visual distinction:
  - [ ] Red Team — neon crimson `#ff2244`; FoxyProxy + HackTools pinned to toolbar
  - [ ] OSINT — neon amber `#ffd000`; developer tools area separator
  - [ ] Puppet Master — neon green `#00e676`; container tab strip always visible
- [ ] Developer button pinned to toolbar in all profiles
- [ ] Firefox Account sign-in button hidden from all profiles

---

## Phase 7a — Development Environment ✓

**Goal:** Complete Nix development setup without leaving NixOS.

- [x] VS Code module with Nix IDE extension (`modules/vscode.nix`)
- [x] Language server (`nil`) configured with auto-format and linting
- [x] Development dependencies: `nixpkgs-fmt`, `statix`, `deadnix`, `direnv`
- [ ] Git integration in VS Code (GitLens, commit signing)
- [ ] Neovim + Tree-sitter alternative module (optional)

---

## Phase 8 — Tool Layers

**Goal:** RedTeam, OSINT, Privacy, and SDR tool sets as independently selectable modules.

> **Current status:** `modules/security-tools.nix` contains all tools as a single flat module. Phase 8 refactors this into separate, independently selectable modules wired through the flake installer.

- [ ] `modules/tools/redteam.nix` — nmap, metasploit, burpsuite, sqlmap, gobuster, evil-winrm, impacket, crackmapexec, netcat, wireshark, john, hashcat, hydra, aircrack-ng, ghidra, binwalk
- [ ] `modules/tools/osint.nix` — theHarvester, spiderfoot, sherlock, holehe, recon-ng, maltego, ExifTool, metagoofil, photon
- [ ] `modules/tools/privacy.nix` — tor, torbrowser, proxychains-ng, mullvad-vpn, protonvpn, macchanger
- [ ] `modules/tools/sdr.nix` — hackrf, gqrx, gnuradio (RF/SDR toolchain)
- [ ] Refactor `modules/security-tools.nix` into independent modules
- [ ] Wire profile flags from Phase 3 installer into flake outputs
- [ ] `flake.nix` conditionally includes tool modules based on selected profile

---

## Phase 9 — Overlays and Missing Packages

**Goal:** Tools not in nixpkgs are packaged and available.

- [ ] `overlays/default.nix` wired into flake
- [ ] Audit Phase 8 tool lists — identify any tools missing from nixpkgs
- [ ] Write derivations for missing tools or point to community flakes
- [ ] Test all declared tools build and run successfully

---

## Phase 10 — Hardening and Privacy Defaults

**Goal:** System-level privacy and hardening beyond tool selection.

- [ ] Kernel hardening:
  - [ ] `kernel.dmesg_restrict = 1` — restrict dmesg to root
  - [ ] `kernel.kptr_restrict = 2` — hide kernel pointers
  - [ ] `kernel.unprivileged_userns_clone = 0` — disable unprivileged namespaces
  - [ ] `kernel.yama.ptrace_scope = 2` — restrict ptrace
- [ ] Network privacy:
  - [ ] MAC randomization on all interfaces at boot via `systemd-networkd`
  - [ ] UFW firewall with deny-by-default inbound rules
  - [ ] IPv6 privacy extensions enabled
- [ ] systemd hardening:
  - [ ] Disable unnecessary services (avahi, cups, bluetooth by default)
  - [ ] Restrict dmesg access
  - [ ] Harden tmpfiles cleanup
- [ ] Audit:
  - [ ] Verify system does not contact unknown hosts on boot
  - [ ] Baseline network traffic analysis
  - [ ] Document all default network connections and how to disable them

---

## Phase 11 — Polish and Documentation

**Goal:** Someone who has never used NixOS can follow the README and get a working install.

- [ ] ISO tested on real hardware (at least one machine type)
- [ ] README install instructions verified end-to-end
- [ ] CONTRIBUTING.md for people who want to add tools or profiles
- [ ] SECURITY.md documenting hardening decisions and what is not hardened
- [ ] FAQ.md addressing common setup questions
- [ ] Versioned releases with tagged ISOs (v1.0, v1.1, etc.)
- [ ] Release notes for each version
- [ ] GitHub Actions CI to verify flake builds without errors

---

## Deferred / Future Ideas

- Wayland session support once xrdp Wayland backend matures
- Hyprland as an optional power-user layer (declared via Home Manager, opt-in)
- Calamares GUI installer as an alternative to the TUI installer
- ARM64 / Raspberry Pi image target
- Mullvad kill-switch integration at the NixOS firewall level
- Auto-updating tool definitions via flake inputs and pinned tool versions
- Dedicated OSINT VM image — lighter, browser-forward, no pentest tools
- Offline package cache for air-gapped deployments
- Containerized tool environments (podman) for isolation
