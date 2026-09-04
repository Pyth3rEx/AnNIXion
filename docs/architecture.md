# Architecture

How the repository is laid out, why it is laid out that way, and what adding a
tool actually involves.

---

## The shape of it

```
.
├── flake.nix                      # Inputs, outputs, system and user wiring
├── hardware-configuration.nix     # Per-machine — gitignored, never committed
├── VERSION  RELEASE_NAME          # The number and the codename
│
├── catalog/                       # One file per tool. See below.
├── system/                        # NixOS modules
│   ├── core/                      # Boot, networking, nix, locale, audio, users
│   ├── vpn/                       # The kernel killswitch, one file per program
│   └── desktop.nix  xrdp.nix  hardening.nix  docker.nix  …
├── home/                          # Home Manager — the operator's environment
│   ├── desktop/                   # Plasma, the application menu, the icon theme
│   ├── firefox/                   # The four profiles and their policies
│   ├── apps/                      # Konsole, VSCodium, OnlyOffice, fastfetch
│   └── shell/                     # Zsh, oh-my-posh and its theme
│
├── iso/  branding/  scripts/      # The live image, its artwork, the tools that build it
├── assets/                        # Wallpapers, the mark, bookmarks, the Burp CA
├── tests/{system,shell,repo}/     # VM tests · built-system fixtures · CI fixtures
├── user/                          # Personal overrides — never committed upstream
└── docs/
```

Two rules decide where anything goes:

1. **A file holds one concern.** `system/vpn/` is nine files because the
   killswitch is six programs, an option tree and the wiring between them — not
   because nine is a nicer number than one.
2. **A name says what is inside it.** `system/` is system modules, `home/` is the
   user environment, `scripts/` is things you run. Nothing is called `modules/`
   or `utils/`.

---

## The catalog

Every security tool used to be declared three times: its package in the tool
module, its `.desktop` entry in the menu module, and its icon in the mark file.
Three lists, the same kill-chain headings typed into each, kept in step by hand.
Adding one tool meant three edits in three trees, and nothing caught a drift.

`catalog/` is the one declaration. **The directory tree is the menu tree:**

```
catalog/
├── bodies.nix                  drawings worn by more than one mark
├── recon/
│   ├── _menu.nix               "01. Reconnaissance"
│   ├── passive/
│   │   ├── _menu.nix           "Passive OSINT" → X-AnNIXion-Recon-OSINT
│   │   ├── theharvester.nix    ← a tool
│   │   ├── whois.nix
│   │   └── …
│   ├── scanning/  rf/
├── weapon/  delivery/  exploit/  install/  c2/  postex/  forensics/  re/
├── sniffing/  tools/  system/
├── browsers/                   the four Firefox profile marks
└── support/                    installed system-wide but never shown
```

A directory holding `_menu.nix` **is** a menu node. Every other `.nix` beside it
is a tool inside that node. `catalog/default.nix` finds both with
`builtins.readDir`, so **nothing registers a tool anywhere** — the file being
there is the registration.

Three consumers read it, and none of them holds a list:

| Consumer | What it derives |
|---|---|
| `system/security-tools.nix` | `environment.systemPackages` |
| `home/desktop/apps-menu.nix` | the `.desktop` entries, the `.directory` files, and the menu XML |
| `home/desktop/icons/` | the icon theme |

---

## Adding a tool

One file. Put it in the phase it belongs to:

```nix
# catalog/recon/scanning/nmap.nix
{ bodies }:
{
  package     = p: p.nmap;
  name        = "Nmap";
  genericName = "Network Scanner";
  comment     = "Network exploration and security auditing";
  exec        = "nmap";
  launch      = "hold";
  mark = {
    class = "probe";
    body  = ''<path d="…"/>'';
  };
}
```

| Field | Meaning |
|---|---|
| `package` | A function of `pkgs`. `null` for something the desktop already ships. |
| `name`, `genericName`, `comment` | What the menu entry says. |
| `exec` | The command. `@home@` is replaced with the home directory. |
| `launch` | `gui` runs it directly · `term` in a konsole that closes with it · `hold` keeps the shell open afterwards · `named` gives the window its own WM_CLASS (then set `wmName`) |
| `mark` | The drawing and its semantic class. See [visual-identity.md](visual-identity.md). |
| `aliases` | Stock icon names to install the mark under, for an app that ships its own `.desktop`. |
| `alsoIn` | Another node path, for a tool that earns a place under a second phase. |

The category comes from the path — `catalog/recon/scanning/` is
`X-AnNIXion-Recon-Scanning`. Nothing retypes it.

Take the lambda head to `_:` if the mark does not use a shared drawing;
`deadnix` will tell you.

Then:

```bash
nix develop --command bash tests/shell/catalog.sh     # the invariants
nix develop --command bash tests/shell/menu-icons.sh  # every Icon= resolves
```

### A drawing worn by more than one mark

The four browser profiles share one body and differ only in class colour; so do
the three terminals; so does a menu directory that wears its signature tool's
mark. Those live in `catalog/bodies.nix` and are referenced by name, which is
what stops a redraw drifting between the variants.

---

## Why the tests are split three ways

| Directory | Kind | Level | What it proves |
|---|---|---|---|
| `tests/system/` | `nixosTest`, boots a VM | L3 | A system behaves correctly once running |
| `tests/shell/` | Fixture, drives a real script | L0 | A claim about the built system holds |
| `tests/repo/` | Fixture | L0 | CI and repository automation decide correctly |

The flake discovers `tests/system/` rather than listing it, so a VM test that is
written and wired in cannot silently never run. See
[testing.md](testing.md) for the rule that every feature ships with its tests.

---

## Overriding any of it

Nothing here needs editing to make the system yours. Base options are all
`lib.mkDefault`, and `user/configuration.nix` and `user/home.nix` are merged
last, so anything you write there wins without `lib.mkForce`. See
[customization.md](customization.md) and [user/README.md](../user/README.md).
