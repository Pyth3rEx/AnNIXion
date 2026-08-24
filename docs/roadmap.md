# AnNIXion Roadmap

Development is organized in phases. Each phase produces a working, testable artifact before the next begins.

---

## Phase 1 — Flake Scaffold and ISO Build Target ✓

**Goal:** A flake that builds a bootable ISO.

- [x] `flake.nix` with inputs: `nixpkgs`, `home-manager`, `plasma-manager`
- [x] `configuration.nix` — locale, timezone, basic kernel params
- [x] Base system configuration functional
- [x] `iso.nix` — minimal ISO build target, boots to shell with auto-login
- [x] ISO builds with `nix build .#packages.x86_64-linux.iso`
- [x] ISO size gate in CI — fails if ISO exceeds 1900 MB (GitHub release limit)

---

## Phase 2 — Disk Layout and Full Disk Encryption

**Goal:** The ISO can partition a disk, set up LUKS2 encryption, and install NixOS.

- [ ] LUKS2 encryption offered by `annixion-install`, on by default — `cryptsetup` on the root partition, unlocked as `cryptroot`, ESP left unencrypted
- [ ] Passphrase read twice and passed to `cryptsetup` over stdin (`--key-file -`, no trailing newline, so the key matches what is typed at the boot prompt)
- [ ] Installer verifies `nixos-generate-config` emitted `boot.initrd.luks.devices` and aborts before `nixos-install` if it did not — otherwise the install succeeds and produces a system whose initrd never asks for a passphrase
- [ ] Document the keymap trap: the passphrase is typed at the boot prompt under the console keymap (US by default), not the layout used during install
- [ ] Tested in a VM: full install with encryption passphrase, boots successfully, decrypts on boot

> **disko is not planned.** The layout is already declared, in fifteen lines of
> `parted`. disko's payoff is btrfs subvolumes and impermanence, neither of
> which is on the roadmap; revisit only if they arrive. Encryption does not
> depend on it either way.

---

## Phase 3 — Installer ✓ (basic) / In Progress (full)

**Goal:** Running `annixion-install` from the live ISO walks through the full setup interactively.

- [x] `scripts/annixion-install` — guided bash installer bundled into the ISO
- [x] Disk selection with confirmation
- [x] GPT partitioning: ESP + root
- [x] Formats, mounts, clones config, generates hardware config, runs `nixos-install`
- [x] Installer available in live session as `annixion-install`
- [x] Auto-elevates via `sudo`, mounts by device node (no udev race), stages the generated `hardware-configuration.nix` for the flake
- [x] Installs the config to `~/.dotfiles` (its canonical location) and hands ownership to `operator` so runtime assets (wallpaper, icons, certs) resolve
- [ ] Refuse to run on legacy BIOS: check `/sys/firmware/efi` before the sudo re-exec, so a machine booted in CSM mode is turned away before any disk is touched rather than failing at the boot loader with the disk already wiped
- [ ] Whiptail TUI for disk selection and options (currently plain readline prompts)
- [ ] Encryption passphrase prompt (see Phase 2)
- [ ] Hostname prompt (pre-filled with random `DESKTOP-XXXXXXX` style name)
- [ ] Username and password prompt
- [ ] Timezone selection (searchable list)
- [ ] Keyboard layout selection, written as `console.keyMap` — also what the LUKS prompt uses
- [ ] Profile selection (RedTeam, OSINT, Privacy — multi-select)
- [ ] Secure Boot: offer key creation and enrolment (see Phase 10)
- [ ] Error handling: graceful rollback on failed partitioning or install
- [ ] Fix: the script ends on `[[ ... ]] && reboot`, so declining the reboot makes a successful install exit 1

### `user/` as the install profile

The installer generates the user config on a first install and consumes it on
later ones, so an install is reproducible from a folder the operator already
owns — no second config format.

- [ ] First install writes the answers (username, password hash, hostname, timezone, keymap, encryption, profiles) into `user/configuration.nix` and `user/home.nix`
- [ ] `--user-config <path|git-url>` imports an existing folder and skips the prompts it covers
- [ ] Disk selection stays interactive in both modes — it describes the machine in front of you, not a preference
- [ ] Validate a provided config **before the disk is wiped**: copy `ci/hardware-stub.nix` into place and `nix eval` the toplevel `drvPath`, so an incompatible config costs seconds instead of a formatted disk
- [ ] Strip `system.stateVersion` and hardware-shaped settings on import — stateVersion is machine state, and inheriting an old one silently changes stateful defaults with no error
- [ ] Retire the shared `hashedPassword` in `flake.nix`, which ships one password hash to every install, in favour of the one collected at install time
- [ ] Document that the `user/` folder is secret-bearing once it holds a password hash
- [ ] Note that a provided config is arbitrary Nix evaluated as root during install — pulling one from a URL is code execution from that source

### Handling configs from older AnNIXion versions

Only what the installer generated can be migrated mechanically; hand-written Nix
can be detected but not rewritten.

- [ ] `modules/compat.nix` using `lib.mkRenamedOptionModule` / `mkRemovedOptionModule` for the `annixion.*` namespace — adopt as policy now, while there is almost nothing to rename
- [ ] Write a version stamp (`user/.annixion-version`) at generation and check it on import
- [ ] On eval failure, offer edit / continue without the config / abort rather than a bare abort
- [ ] `annixion-config-doctor` — same validation, runnable before `rebuild` on an installed system
- [ ] `docs/migration.md` per breaking release

### Installing onto an existing partition

- [ ] Install to a chosen partition, not only a whole disk — skip `mklabel`, and reuse the ESP that is already there instead of reformatting it, since a shared ESP carries another OS's boot entries
- [ ] Show the surrounding partitions in the confirmation, so it is clear what is *not* being touched
- [ ] Set `boot.loader.systemd-boot.configurationLimit` when reusing a small ESP — a 100 MiB Windows ESP fills after a few NixOS generations and breaks rebuilds

### Testing

- [ ] `tests/installer.sh` — run the installer with every destructive command stubbed and assert the device sequence, the encryption branches and the LUKS guard; wire in as `checks.installer` and in CI. No disk, no VM, no network
- [ ] Manual VM install before each release — the stub test proves the right commands are issued, not that the result boots

---

## Phase 4 — Base System and User Environment ✓

**Goal:** A clean, minimal installed system that boots to a working desktop.

- [x] Default non-root user (`operator`), sudo via wheel group
- [x] Home Manager wired into flake — single `nixos-rebuild switch` handles system + user config
- [x] ZSH with autosuggestions, fast-syntax-highlighting, fzf widget integration
- [x] oh-my-zsh + oh-my-posh red-team prompt with git, exec time, exit code, clock
- [x] zoxide, fzf-tab, you-should-use, autopair, urltools, jsontools, dirhistory
- [x] tmux, xterm terminal, git declared via Home Manager
- [x] `nix.gc` — automatic weekly cleanup of old generations
- [x] `modules/` — modular structure: `desktop.nix`, `xrdp.nix`, `security-tools.nix` (shell/user config lives under `home/`)
- [ ] `modules/base/users.nix` — user management as a standalone module
- [x] Additional shell environment: `direnv` integration via `programs.direnv` and `nix-direnv`

---

## Phase 5 — Desktop Environment ✓

**Goal:** A functional desktop accessible to both technical and non-technical operators.

**Decision: KDE Plasma 6 on X11**

Rationale:
- Broadest audience compatibility — familiar paradigm for operators coming from Windows
- Full keyboard-driven workflow available via KRunner and Krohnkite tiling
- Stable X11 session required for reliable xrdp/Enhanced Session support
- Wayland (Plasma 6) available as a future upgrade path once xrdp Wayland support matures

- [x] KDE Plasma 6 declared in `modules/desktop.nix`; per-user Plasma settings extracted to `home/plasma.nix` (plasma-manager)
- [x] SDDM login manager with Breeze theme
- [x] Krohnkite tiling script enabled (i3-style auto-tiling within Plasma)
- [x] KDE shortcuts via `plasma-manager`: Meta+1-4 desktops, Meta+Return terminal, Meta+Q close
- [x] Breeze Dark theme set as default
- [x] 4 virtual desktops preconfigured
- [x] Theming pass — Breeze Dark, Slot Nord Dark icons, Nordzy cursor, JetBrains Mono
- [x] Application launcher and taskbar layout declared in Nix
- [x] Custom wallpaper and visual identity pass

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
- [x] Audio passthrough verified end-to-end

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
- [x] `home/firefox/redteam.nix` — Red Team profile: HackTools, Wappalyzer, Cookie Editor, Retire.js; search engines: Exploit-DB, CVE, NVD
- [x] `home/firefox/osint.nix` — OSINT profile: NoScript, CanvasBlocker, User-Agent Switcher, Cookie AutoDelete; search engines: Shodan, Censys, Wayback Machine
- [x] `home/firefox/puppet.nix` — Puppet Master profile: Multi-Account Containers, Temporary Containers, CanvasBlocker, User-Agent Switcher, NoScript; search engines: Yandex, Baidu, social search
- [x] Desktop launchers for each profile via `xdg.desktopEntries`
- [x] Burp proxy set at profile level (`network.proxy.*`) rather than via FoxyProxy, so interception does not depend on a third-party extension (#25); `failover_direct = false` blocks leaks if Burp is down. FoxyProxy stays installed for ad-hoc switching, shipped disabled with the Burp entry as a worked example
- [x] VPN enforcement rebuilt in the kernel (`modules/vpn-enforcement.nix`, #21/#26): enforced applications run in a dedicated cgroup slice, an nftables rule permits egress only via a tunnel interface, and `annixion-vpn-browser` / `annixion-vpn-run` hard-fail when no tunnel is up. Replaces the old SOCKS5 placeholder at 127.0.0.1:1080, which nothing ever served
- [x] VPN enforcement covers OSINT and Puppet Master. Red Team was enforced too until #37: an attribution control gating a reachability workflow made the profile unusable on internal engagements, where the target is on the LAN and no tunnel is involved. It now launches direct, with `annixion-vpn-browser "Red Team"` available when the tunnel is wanted — and Burp must go through `annixion-vpn-run` alongside it, since the browser only reaches loopback
- [ ] ResistFingerprinting flags wired in OSINT profile settings
- [x] Per-profile custom `userChrome.css` for immediate visual distinction:
  - [x] Red Team — neon crimson `#ff2244`; FoxyProxy + HackTools pinned to toolbar
  - [x] OSINT — neon amber `#ffd000`
  - [x] Puppet Master — neon green `#00e676`; container tab strip always visible
- [x] Developer button pinned to toolbar in all profiles
- [x] Firefox Account sign-in button hidden from all profiles

---

## Phase 7a — Development Environment ✓

**Goal:** Complete Nix development setup without leaving NixOS.

- [x] VSCodium module with Nix IDE extension (`home/vscodium.nix`)
- [x] Language server (`nil`) configured with auto-format and linting
- [x] Development dependencies: `nixfmt`, `statix`, `deadnix`
- [x] `direnv` integration via `programs.direnv` and `nix-direnv`
- [ ] Git integration in VSCodium (GitLens, commit signing)
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

Pass one landed in `modules/hardening.nix` — see [hardening.md](hardening.md).
Everything below is what remains; the next pass gets its own branch.

- [x] Kernel hardening:
  - [x] `kernel.dmesg_restrict = 1` — restrict dmesg to root
  - [x] `kernel.kptr_restrict = 2` — hide kernel pointers
  - [x] `kernel.yama.ptrace_scope` — set to `1`, not the `2` originally planned: `2` breaks `gdb ./target` and `strace -f`, which this distro exists to run
  - [ ] ~~`kernel.unprivileged_userns_clone = 0`~~ — **not doing this**: it breaks bubblewrap, which `annixion-vpn-run` uses to confine DNS, and Firefox's own content sandbox
- [ ] Secure Boot:
  - [ ] `lanzaboote` flake input and module, replacing `systemd-boot`
  - [ ] Opt-in (`annixion.secureBoot.enable`, default off) — it cannot be on by default, because the PKI bundle only exists after `sbctl create-keys` has run on that machine, and enabling it blind makes the next `rebuild` unbootable
  - [ ] Helper command wrapping `sbctl create-keys` and `enroll-keys --microsoft` (keeping Microsoft's certs, or option ROMs and any dual-booted OS stop validating)
  - [ ] Document the flow: the ISO cannot ship Secure Boot–bootable without a Microsoft-signed shim, so it is install with SB off → enrol keys → turn SB on
  - [ ] Note the storage dependency: the PKI bundle must live on persistent storage, so this lands after encryption
- [ ] Boot chain, other:
  - [ ] Move to `boot.initrd.systemd` — upstream drops scripted stage 1 in 26.11
- [ ] Network privacy:
  - [x] Firewall with deny-by-default inbound rules (NixOS firewall, no ports open — not UFW)
  - [ ] MAC randomization on all interfaces at boot
  - [ ] IPv6 privacy extensions enabled
- [ ] systemd hardening:
  - [x] Disable unnecessary services (OpenSSH, ModemManager, geoclue, fwupd, avahi, printing, KDE PIM)
  - [ ] Unit sandboxing for the services that remain — xrdp first, it is the only remotely reachable one
  - [ ] Harden tmpfiles cleanup
- [ ] Accounts:
  - [ ] Retire the shared `operator` password hash (see Phase 3)
- [ ] Audit:
  - [ ] Verify system does not contact unknown hosts on boot
  - [ ] Baseline network traffic analysis
  - [ ] Document all default network connections and how to disable them

---

## Phase 11 — Polish and Documentation ✓ (partial)

**Goal:** Someone who has never used NixOS can follow the README and get a working install.

- [ ] ISO tested on real hardware (at least one machine type)
- [x] Install instructions cover both ISO and existing-NixOS paths
- [x] `CONTRIBUTING.md` for people who want to add tools or profiles
- [x] `SECURITY.md` documenting hardening decisions and what is not hardened
- [x] `docs/faq.md` addressing common setup questions
- [x] Versioned releases with tagged ISOs (semantic versioning via `VERSION` file)
- [ ] Release notes per version
- [x] GitHub Actions CI — flake eval, system closure build, VM tests, ISO build + size gate, release publish
- [ ] Sign the ISO in CI — publish `SHA256SUMS` and a detached GPG signature over it, signing key in Actions secrets, public key committed and fingerprint in the README. Today the release job uploads the raw ISO with no checksum and no signature
- [ ] Document UEFI as a requirement — the ISO is a hybrid image and boots happily in legacy mode, then fails at the very end of the install with the disk already wiped. Requirements section, the Rufus setting that produces a UEFI stick (`GPT` + `UEFI (non CSM)`), the firmware settings to change, and the `ls /sys/firmware/efi` check
- [ ] Document the one BIOS path that does work: an existing BIOS-booted NixOS install can override `boot.loader.systemd-boot.enable` (it is `mkDefault`) and keep GRUB — disabling systemd-boot explicitly is required or NixOS trips its one-boot-loader assertion

---

## Non-goals

- **Legacy BIOS / CSM boot.** AnNIXion is UEFI-only: `systemd-boot` is a UEFI
  boot loader and the installer writes GPT + ESP. Supporting BIOS would mean a
  second boot loader path, a second partition layout and a second CI target, to
  serve hardware that predates the tooling this distro ships.
- **disko.** See Phase 2.

---

## Deferred / Future Ideas

- Wayland session support once xrdp Wayland backend matures
- Hyprland as an optional power-user layer (declared via Home Manager, opt-in)
- Calamares GUI installer as an alternative to the bash installer
- ARM64 / Raspberry Pi image target
- Mullvad kill-switch integration at the NixOS firewall level
- Auto-updating tool definitions via flake inputs and pinned tool versions
- Dedicated OSINT VM image — lighter, browser-forward, no pentest tools
- Offline package cache for air-gapped deployments
- Containerized tool environments (podman) for isolation
