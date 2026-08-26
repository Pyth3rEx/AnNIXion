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

ZSH configuration lives in `home/zsh/` — `default.nix` for the shell,
`oh-my-posh.nix` for the prompt. See [docs/zsh.md](zsh.md) for the full shortcut and alias reference, and [docs/tools.md](tools.md) for enhanced CLI tools included in the environment.

---

## Desktop panel

The top bar is declared in `home/plasma.nix` under `programs.plasma.panels`, and
is organised by function into three groups:

```
[desktops][tasks]───[☰][app name]───[cam][net][BT][vol][bat][tray][clock][◆]
```

| Group | Contents |
|---|---|
| Left | Virtual desktop pager, icon-only task manager pinned to the quicklaunch set |
| Centre | Compact app menu, then the focused app's name |
| Right | Camera indicator, system categories, status tray, clock, application menu |

Each right-hand applet owns one category and carries its state in its own icon —
signal strength, mute, charge — so the bar reads at a glance without opening
anything. The system tray holds the rest (clipboard, devices, screens, media
controls) and is where future status indicators belong, via `items.extra`.

Two things to know before editing the widget list:

An applet placed on the bar directly must **also** appear in the tray's
`items.hidden`, or it renders twice — once standalone, once in the tray.

The task manager's `launchers` mirror `hotkeys.commands` in `Meta+F<N>` order,
so the Nth icon is the Nth key. Adding a quicklaunch key means adding its
`.desktop` id here too. Where an app has both a stock entry and an `annixion-*`
one, pin the stock id: Plasma matches a running window to a launcher by window
class, and `annixion-wireshark` does not resolve against a window whose class is
`wireshark`. The ids with no stock equivalent — the root and Metasploit
terminals, the Firefox profiles, VSCodium — carry their own `StartupWMClass`
instead.

A panel change does not appear on `rebuild`. plasma-manager applies panels with a
Plasma desktop script that runs at login, and it deletes and regenerates
`plasma-org.kde.plasma.desktop-appletsrc` when it does. Log out and back in.

### Centring

The two expanding spacers do the work. Plasma sizes a pair of them so that
whatever sits between them lands on the panel centre, whatever the flanking
groups weigh — so the centre group stays put as the task manager grows. Put
nothing else between the left group and the first spacer: a fixed-length pad
there is added on top of the centring, and pushes the centre group right.

`applicationTitleBar` is pinned to a constant width so the group does not
shuffle as app names change length, and the name is centred inside that width
rather than hugging its left edge.

The applet ships with `widgetActiveTaskFilterByScreen` on, which limits it to
windows living on the panel's own display — with more than one monitor the name
blanks out as soon as focus moves elsewhere. `behavior.filterByScreen = false`
turns that off, so the bar names whatever is focused, on any screen.

---

## Keyboard

Shortcuts live in `home/plasma.nix`: window and desktop keys under
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
| `Meta+F4` | Firefox — Red Team |
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
`annixion-raise` (`home/window-raise.nix`), which matches a glob against every
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

VSCodium ships as part of the base user environment (`home/vscodium.nix`) with full Nix language support out of the box:

- **Language server:** `nil` — code completion and diagnostics
- **Formatting:** `nixfmt` — auto-format on save, 2-space indentation
- **Linting:** Real-time error detection with `statix` and `deadnix`
- **direnv:** Automatic environment loading via `nix-direnv`

No manual activation needed — it is included by default. Open VSCodium after the first `rebuild`.

---

## Adding tools

System packages are declared in `modules/security-tools.nix`. Add any nixpkgs package to the `environment.systemPackages` list and rebuild.

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
