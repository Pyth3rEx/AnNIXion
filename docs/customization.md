# Customization

How to change AnNIXion without touching shared configuration: the `user/`
override system, adding tools, and the development environment.

---

## User override system

All base config options use `lib.mkDefault`, so settings in `user/` win automatically — no `lib.mkForce` needed (except for Firefox proxy prefs, see [usage.md](usage.md)).

The `user/` directory is never committed upstream. It survives reinstalls when you clone your own fork.

### Getting started

**Set your git identity** — uncomment the example in `user/home.nix`:

```nix
imports = [ ./examples/git.nix ];
```

Then fill in `user/examples/git.nix` with your details.

**Add or override ZSH settings** — uncomment the ZSH example:

```nix
imports = [ ./examples/zsh.nix ];
```

Apply any change with:

```bash
rebuild
```

See `user/README.md` for the full override system documentation.

---

## Shell environment

ZSH configuration lives in `home/shell/` — `default.nix` for the shell,
`oh-my-posh.nix` for the prompt. See [docs/zsh.md](zsh.md) for the full shortcut and alias reference, and [docs/tools.md](tools.md) for enhanced CLI tools included in the environment.

---

## Desktop compositing

The compositor is off by default. The deployment target is a Hyper-V guest,
where `hyperv_drm` gives a KMS display device and no render node, so KWin would
composite every frame through Mesa's llvmpipe software rasterizer — about three
quarters of a core, continuously, on a machine meant to be running security
tooling.

Check whether this machine has acceleration:

```bash
ls /dev/dri/renderD*     # a node here means the GPU can do the work
```

If one exists, turn the compositor on in `user/configuration.nix`:

```nix
annixion.desktop.compositing = true;
```

| | Compositing off (default) | Compositing on |
|---|---|---|
| Blur and transparency | None — the panel renders opaque | As themed |
| Desktop animations | None | At `AnimationSpeed = 3` |
| Screen tearing | Visible | Absent |
| Cost with no render node | None | ~75% of a core, continuously |

Krohnkite tiling, virtual desktops, the panel and every keyboard shortcut work
the same either way. Over an Enhanced Session the visual loss is small — the
RDP client is already re-encoding the framebuffer.

KWin 6 has no cheaper middle ground: the X11 XRender compositor was removed, so
it is OpenGL-through-llvmpipe or nothing. It also dropped the D-Bus method that
used to suspend compositing live, so this setting only takes effect on
`rebuild` and a fresh session.

---

## Offensive networking

The base firewall drops all inbound traffic, which also drops the callback from a
reverse shell — the exploit completes but no session lands. `annixion.offensiveNet`
is an opt-in runtime toggle that opens inbound on the engagement VPN interface and
relaxes the redirect/MITM sysctls, armed per session and gone on reboot.

```nix
annixion.offensiveNet.enable = true;
# annixion.offensiveNet.trustedInterfaces = [ "tun0" "wg0" ];  # default [ "tun0" ]
```

Enabling installs the toggle but leaves the box hardened at boot. Arm and disarm it
for the session:

```
annixion-offensive on | off | status
```

The same toggle appears in the control centre (`annixion-cc`) when the module is
enabled. Full behaviour, scope and caveats: [docs/hardening.md](hardening.md).

---

## Wireless

`wpa_supplicant` is off by default. NetworkManager's wifi backend defaults to
it and turns `networking.wireless` on unconditionally, so on a Hyper-V guest —
which has no radio at all — the daemon runs for the whole uptime with nothing
to manage.

Check whether this machine has one:

```bash
ls /sys/class/ieee80211    # a directory here means there is a radio
```

If it exists, turn wireless on in `user/configuration.nix`:

```nix
annixion.hardware.wireless = true;
```

Ethernet, the OpenVPN plugin and the VPN killswitch are unaffected either way —
this only governs whether NetworkManager has a wifi backend to drive.

---

## Reporting platform

SysReptor runs locally and holds client findings, so it ships loopback-only and
encrypted at rest, with the Hack The Box report designs imported on first
start. The settings live under `annixion.sysreptor`:

```nix
annixion.sysreptor = {
  user = "operator";            # the login created on first start
  hashedPassword = "pbkdf2_sha256$600000$...";  # `sysreptor hash` mints one
  designs = [ "htb" "offsec" ]; # official design packs to import
  # networkAccessible = true;   # publishes it on every interface, opens the port
};
```

The login ships with the same password as the operator account, so change it —
in the UI, or by putting a fresh `sysreptor hash` here. There is no login-less
mode: skipping the login screen is a Professional-edition feature.

`networkAccessible` is the one with teeth: it serves every engagement's
deliverables over plain HTTP to anything that can route here. Options,
defaults and the reverse-proxy shape: [docs/sysreptor.md](sysreptor.md).

---

## Resource limits

Three bounds ship as defaults, each overridable in `user/configuration.nix`:

| | Default | Why |
|---|---|---|
| `services.journald.extraConfig` | `SystemMaxUse=512M` | With no cap journald takes 10% of the filesystem — a ~19 GB ceiling on a 195 GB root |
| `zramSwap.enable` | `true` | No swap at all means a heavy scan or parallel build meets the OOM killer instead of degrading |
| `nix.optimise.automatic` | `true` | Hardlinks identical files in the store; a toolchain-heavy closure carries a lot of them |

The journal stays `Storage=persistent`: boot and killswitch behaviour is
exactly what it gets read for, and those are the logs a volatile journal would
lose. Raise the cap if an engagement needs longer history:

```nix
services.journald.extraConfig = "SystemMaxUse=2G";
```

Store optimisation is a space/time trade with no semantic effect — unlike a
shorter GC window, which reclaims space by discarding rollback targets.

---

## Desktop panel

The top bar is declared in `home/desktop/plasma/` under `programs.plasma.panels`, and
is organised by function into three groups:

```
[desktops]│[tasks]───[☰][app name]───[cam][net][BT][vol][bat][tray][clock][◆]
```

| Group | Contents |
|---|---|
| Left | Virtual desktop pager, a rule, icon-only task manager pinned to the everyday six |
| Centre | Compact app menu, then the focused app's name |
| Right | Camera indicator, system categories, status tray, clock, application menu |

Each right-hand applet owns one category and carries its state in its own icon —
signal strength, mute, charge — so the bar reads at a glance without opening
anything. The system tray holds the rest (clipboard, devices, screens, media
controls) and is where future status indicators belong, via `items.extra`.

Two things to know before editing the widget list:

An applet placed on the bar directly must **also** appear in the tray's
`items.hidden`, or it renders twice — once standalone, once in the tray.

The task manager pins six launchers — the two terminals, the file manager and
the three Firefox profiles — in `Meta+F<N>` order, so they read as `F1`
through `F6`. That is a subset of `hotkeys.commands`, not a mirror of it:
everything else keeps its key and its menu entry without spending panel width.
Adding a quicklaunch key does not oblige you to pin it. Where an app has both
a stock entry and an `annixion-*` one, pin the stock id: Plasma matches a
running window to a launcher by window class, and `annixion-wireshark` does
not resolve against a window whose class is `wireshark`. The ids with no
stock equivalent — the root terminal, the Firefox profiles — carry their own
`StartupWMClass` instead.

The rule between the pager and the launchers is `com.annixion.separator`, a
two-file KPackage written by `home/desktop/panel-separator.nix`. Plasma 5's
`org.kde.plasma.marginsseparator` is gone in Plasma 6 with nothing in its place,
so it is ours. It draws a hairline in the theme's text colour and costs about
six pixels; being fixed-length and left of the first spacer, it shifts the
centre group right by half that.

`Meta+F4` and the Red Team icon both run `annixion-redteam`
(`home/desktop/redteam-launch.nix`), which starts Burp Suite if `pgrep -f burpsuite`
finds none running and then execs the browser profile. Burp is matched on its
command line, not its window: the JVM shows nothing for several seconds, and a
window test would start a second copy for every click in that gap. Note that
Plasma raises an existing window rather than re-running `Exec`, so a Red Team
window that is already open will not pull Burp up behind it — close it first, or
launch Burp from the menu.

A panel change does not appear on `rebuild`. plasma-manager applies panels with a
Plasma desktop script that runs at login, and it deletes and regenerates
`plasma-org.kde.plasma.desktop-appletsrc` when it does. Log out and back in.

### Centring

The two expanding spacers do the work. Plasma sizes a pair of them so that
whatever sits between them lands on the panel centre, whatever the flanking
groups weigh — so the centre group stays put as the task manager grows. Be
sparing with anything else left of the first spacer: a fixed-length pad there is
added on top of the centring, and pushes the centre group right by half its
width. The separator is the one such pad, and it is a hairline for that reason.

`applicationTitleBar` is pinned to a constant width so the group does not
shuffle as app names change length, and the name is centred inside that width
rather than hugging its left edge.

The applet ships with `widgetActiveTaskFilterByScreen` on, which limits it to
windows living on the panel's own display — with more than one monitor the name
blanks out as soon as focus moves elsewhere. `behavior.filterByScreen = false`
turns that off, so the bar names whatever is focused, on any screen.

---

## Keyboard

Shortcuts live in `home/desktop/plasma/`: window and desktop keys under
`shortcuts.kwin`, launchers under `hotkeys.commands`.

| Keys | Action |
|---|---|
| `Meta+1..4` | Switch to virtual desktop 1-4 |
| `Meta+Ctrl+1..4` | Move the active window to desktop 1-4 |
| `Meta+F1..F12` | Launch or focus an application (below) |
| `Meta+Return` | Run command |
| `Alt+Space` | KRunner |
| `Meta` | Tiled Menu |

`Meta+Ctrl+N` moves the window without following it — the window leaves for
the target desktop and you stay where you are.

### Window and focus

| Keys | Action |
|---|---|
| `Meta+Up` | Maximize |
| `Meta+Down` | Minimize |
| `Meta+F` | Fullscreen |
| `Alt+F4` | Close |
| `Meta+Shift+↑↓←→` | Move focus between windows — Krohnkite uses these |

### Applications

Grouped in three bands: heavy use, offensive, then work.

| Key | Application |
|---|---|
| `Meta+F1` | Konsole |
| `Meta+F2` | Konsole as root — red background, `sudo -i` |
| `Meta+F3` | Dolphin |
| `Meta+F4` | Firefox — Red Team, with Burp Suite behind it |
| `Meta+F5` | Firefox — OSINT |
| `Meta+F6` | Firefox — Puppet Master |
| `Meta+F7` | Burp Suite |
| `Meta+F8` | Metasploit |
| `Meta+F9` | Wireshark |
| `Meta+F10` | Ghidra |
| `Meta+F11` | VSCodium |
| `Meta+F12` | Obsidian |

### Launch or focus

These keys do not start a second copy of a running app. Each one calls
`annixion-raise` (`home/desktop/window-raise.nix`), which matches a glob against every
window's `WM_CLASS`, activates the first hit, cycles through the rest on
repeated presses, and only runs the command when nothing matches.

That only works where the windows are distinguishable, and two cases are not by
default:

Every Firefox profile reports the same `WM_CLASS`. The desktop entries in
`home/firefox/default.nix` set `MOZ_APP_REMOTINGNAME` per profile — that is what
turns the class into `firefox-red`, `firefox-osint`, `firefox-puppet` — and
`StartupWMClass` so the panel matches windows to launchers.

Every Konsole reports `konsole` too, so the root and Metasploit terminals pass
`-name konsole-root` / `-name konsole-msf`, which sets the `WM_CLASS` instance.
The plain-Konsole key matches `konsole.konsole` exactly so it never steals them.

`annixion-raise` talks to the window manager through `wmctrl`, so it is X11-only.
A Wayland session would need `kdotool` in its place.

---

## Development environment

VSCodium ships as part of the base user environment (`home/apps/vscodium.nix`) with full Nix language support out of the box:

- **Language server:** `nil` — code completion and diagnostics
- **Formatting:** `nixfmt` — auto-format on save, 2-space indentation
- **Linting:** Real-time error detection with `statix` and `deadnix`
- **direnv:** Automatic environment loading via `nix-direnv`

No manual activation needed — it is included by default. Open VSCodium after the first `rebuild`.

Two reading aids ride along, both purely visual: `better-comments` colours a
comment by its marker — `!` for a warning, `?` for a query, `TODO` for work
left — and `indent-rainbow` tints each indent level, which is what makes a
deeply nested Nix attribute set or a long `if` in a shell script readable at a
glance.

### C/C++ toolchain

VSCodium also ships `clangd` (language server, formatter), `codelldb` and
`cmake-tools` for C/C++ (`home/apps/vscodium.nix`). `codelldb` is pointed at
the system `lldb` rather than its own bundled copy, so the editor's debugger
and everything below agree on one build. The tools behind them are installed
system-wide from `catalog/support/`: `clang`, `clang-tools`, `gnumake`,
`cmake`, `ninja`, `bear` (generates `compile_commands.json` for Makefile
projects — clangd needs a build system to produce one for), `gdb`, `lldb`,
and `llvm` (`llvm-objdump`, `llvm-nm`, `llvm-readobj`, `llvm-mca` — binary
inspection for RE work). `shellcheck` is there too, system-wide rather than
left to the VSCodium extension, because the extension's bundled binary
doesn't run on NixOS.

`gdb` and `lldb` being on `PATH` also means **Ghidra's Debugger plugin finds
them automatically** — both its GDB and LLDB launch modes default to the
bare binary name, resolved via `PATH`, with nothing to configure. Ghidra's
decompiler is unaffected either way: it works from the binary alone and has
no notion of which compiler produced it.

### Shell scripting

`bash-ide-vscode` runs the bash language server over every `.sh` in the tree
(`home/apps/vscodium.nix`) — completion, hover documentation from the local man
pages, go-to-definition across sourced files, and `shfmt` formatting on save.
It is wired for a machine with no network: nothing it does reaches out, and
`bashIde.explainshellEndpoint` is deliberately left unset, since pointing it at
explainshell.com would post the command line under your cursor to a third
party.

nixpkgs patches the extension to the store `shellcheck` and `shfmt` rather than
the binaries it bundles, so neither needs a path setting. The server's own
shellcheck is then switched off — `bashIde.shellcheckPath` is set to the empty
string — because `timonwong.shellcheck` already reports those findings, and
leaving both on shows every warning twice.

`shfmt` takes its indent width from the editor rather than from a setting of
its own, so the `[shellscript]` block sets `editor.tabSize` to 2 and
`editor.insertSpaces`, and `bashIde.shfmt.caseIndent` supplies the `-ci`. That
is `shfmt -i 2 -ci`, which is how every script in this repository is already
written — without it, the first save reformats the file entirely.

### PowerShell

`pwsh` is installed system-wide from `catalog/tools/dev/powershell.nix` and has
a menu entry under Development, so there is a console to work a script through
rather than only run it. The editor side is `ms-vscode.powershell`, which
brings PowerShell Editor Services, PSReadLine and PSScriptAnalyzer — all three
bundled in the extension as portable assemblies loaded by `pwsh`, so
completion, diagnostics and formatting work with no network and no companion
package.

nixpkgs does not patch this extension the way it patches the bash one: it
looks for `pwsh` on `PATH` and keeps its own list of discovered installs, so
`powershell.powerShellAdditionalExePaths` names the store path explicitly and
`powershell.powerShellDefaultVersion` selects it. Without both, the language
server either never starts or starts against something else.
`powershell.promptToUpdatePowerShell` is off — the version is the flake's to
decide, and the check goes over the network.

`CC` and `CXX` default to `clang`/`clang++` system-wide (`system/toolchain.nix`)
— sharper diagnostics and working sanitizers, and it matches the
clangd/lldb pair above. This only steers build systems that respect
`CC`/`CXX` (make, cmake, autotools); nixpkgs still builds its own packages
with gcc, so nothing here forces a rebuild of the closure.

---

## Adding tools

A tool is one file in `catalog/`, holding its package, its menu entry and its
icon together. Drop it in the kill-chain phase it belongs to and rebuild — the
package list, the `.desktop` entry, the menu XML and the icon theme all follow
from it. There is no list to add it to.

The schema and the fields are in [architecture.md](architecture.md#adding-a-tool).

For tools not in nixpkgs, add a derivation under `overlays/` (see [docs/roadmap.md](roadmap.md) Phase 9).

---

## Versioning

Every PR to `main` must bump the `VERSION` file. CI enforces this and fails the build if the version has not changed.

Follow semantic versioning:

| Change type | Example |
|---|---|
| Bug fix / small tweak | `0.1.0` → `0.1.1` |
| New feature | `0.1.1` → `0.2.0` |
| Breaking change | `0.2.0` → `1.0.0` |

The ISO filename and GitHub release tag are derived from this file automatically.
