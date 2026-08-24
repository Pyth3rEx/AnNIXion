# ZSH Reference

AnNIXion ships a fully configured ZSH environment. Configuration lives in `home/zsh/`:

| File | Contents |
|---|---|
| `home/zsh/default.nix` | Shell settings, aliases, plugins, keybindings, the startup banner |
| `home/zsh/oh-my-posh.nix` | Turns the prompt on for the Home Manager user |
| `home/zsh/omp-theme.nix` | The prompt itself — block layout, segments and colours |

---

## Prompt — oh-my-posh

Defined in `home/zsh/omp-theme.nix`. Two-line powerline-style prompt in accent
red (`#FF4757`) over dark slate greys (`#0E0F13`, `#1A1D24`, `#2E323D`) with
`#DFE4EA` text. Left-block segments open on a solid arrow in their own colour
and close on a solid one traced by an accent red thin arrow; right-block
segments have no opening cap and are split by an accent red `//`.
Path components are split by a plain `/` in accent red, the leading one on
absolute paths included. The second line is a single accent red `$>` prompt
(`#>` when root) with the cursor immediately after it.

Every segment except `user @ host` carries a `min_width`, so a narrow terminal
sheds them one at a time instead of wrapping onto a second line:

| terminal width | segments shown |
| --- | --- |
| < 70 | `user @ host` |
| 70 | `+ path` |
| 105 | `+ git` |
| 120 | `+ exit code` |
| 125 | `+ nix-shell` (only inside one) |
| 135 | `+ clock` |
| 150 | `+ execution time` |
| 165 | `+ command length` |

The thresholds assume a path of about 20 characters; a much longer one can still
wrap at the low end of a band.

Every shell on the machine is zsh and every one of them uses this prompt.
`modules/shell.nix` makes zsh the default login shell for every user including
root, and installs the theme into `/etc/zshrc` and `/etc/bashrc` for anyone Home
Manager does not manage.

Root is managed too: `flake.nix` gives it a Home Manager configuration importing
`home/zsh`, so `sudo su` lands in the same shell — same aliases, plugins,
keybindings and banner — with the session segment flipped to ` ROOT`. The CLI
those aliases call lives in `environment.systemPackages` rather than
`home.packages` so both users have it. Aliases written against `~/.dotfiles`
(`rebuild`, `enix`) look under `/root` when run as root.

Bash cannot be removed from NixOS: it is `/bin/sh`, every build sandbox and
every activation script. What it no longer is, is a shell you land in.
`nix-shell`, `nix develop` and `nix run` all start bash, so `any-nix-shell`
(loaded from `home/zsh/default.nix`) rewrites them to hand the session straight
to zsh. The `❄` segment marks such a shell. The `/etc/bashrc` copy of the prompt
covers the leftovers — `nix-shell --pure`, a bare `bash` — so even those keep the
red prompt.

The separator glyphs live in the Private Use Area, so the terminal font must be
a Nerd Font. Konsole is set to `JetBrainsMono Nerd Font` in `home/konsole.nix`;
a plain font renders the separators as empty boxes.

```
  user @ HOST    ~/path/to/dir    ⎇ main  ●2  +1  ↑3        42c  ⏱ 5s  ✗ 1  14:32:07
$> 
```

| Segment | When shown | Meaning |
|---|---|---|
| `user @ HOST` | Always | Username and hostname. Flips to ` ROOT` on red bg when root |
| `~/path` | Terminal ≥ 70 cols | Current directory, shortened to 4 levels. `~` for home |
| `⎇ branch` | Inside a git repo | Branch or commit SHA |
| `●N` | Staged changes | N files staged |
| `+N` | Working changes | N modified/untracked files |
| `↑N` / `↓N` | Ahead/behind remote | Commits ahead or behind |
| `⚑N` | Stash entries | N stash entries |
| `Nc` (right) | After every command | Character count of the last command |
| `⏱ Xs` (right) | Command ran > 3 s | Execution time, rounded |
| `✗ N` (right) | Non-zero exit | Exit code of the last command |
| `HH:MM:SS` (right) | Terminal ≥ 135 cols | Current time |
| `❄ impure` | Inside nix-shell / nix develop | The shell is a Nix environment |
| `$>` (line 2) | Always | Where you type; `#>` when root |

---

## Key Bindings

### Navigation

| Key | Action |
|---|---|
| `Ctrl+Right` | Jump one word forward |
| `Ctrl+Left` | Jump one word backward |
| `Home` | Jump to start of line |
| `End` | Jump to end of line |
| `Delete` | Delete character under cursor |
| `Ctrl+Backspace` | Delete word to the left |
| `Ctrl+Delete` | Delete word to the right |

### History

| Key | Action |
|---|---|
| `↑` / `↓` | History search matching the current prefix |
| `Ctrl+R` | **fzf interactive history search** with live preview |

### Files and Directories

| Key | Action |
|---|---|
| `Ctrl+T` | fzf file picker — inserts selected path at cursor |
| `Alt+C` | fzf directory picker — cd into selected directory |
| `Alt+←` | Go back in directory history (`dirhistory`) |
| `Alt+→` | Go forward in directory history (`dirhistory`) |

### Convenience

| Key | Action |
|---|---|
| `ESC ESC` | Prepend `sudo` to the current or previous command |
| `Enter` (empty line) | Show `git status` in a repo, `ls` elsewhere (`magic-enter`) |
| `Tab` | **fzf-tab** completion popup — searchable, live preview |

---

## Aliases — System

| Alias | Expands to |
|---|---|
| `ll` | `ls -la` |
| `grep` | `grep --color=auto` |
| `cat` | `bat` (syntax-highlighted pager) |
| `b` | Clears the screen and reprints the startup banner |

## Aliases — NixOS

| Alias | What it does |
|---|---|
| `rebuild` | `sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure` |
| `upgrade` | Update all flake inputs, then rebuild |
| `update` | Update flake inputs only (no rebuild) |
| `enix` | Open `flake.nix` in Kate |
| `emod` | Open `modules/` in Kate |
| `euser` | Open `user/` in Kate |
| `ehome` | Open `home.nix` in Kate |
| `ezsh` | Open `home/zsh/default.nix` in Kate |

## Aliases — Git

| Alias | Expands to |
|---|---|
| `gs` | `git status` |
| `gp` | `git push` |
| `gl` | `git pull` |

## Aliases — Network / OSINT

| Alias | What it does |
|---|---|
| `ip_out` | External IP address (via ifconfig.me) |
| `ip_local` | Local IPv4 addresses with prefix lengths |
| `myip` | Formatted table of all non-loopback interfaces |
| `ports` | `ss -tulnp` — listening TCP/UDP ports with process names |
| `vpn` | Detect active VPN interfaces (tun, wg, vpn prefix) |

## Aliases — Tools

| Alias | Expands to |
|---|---|
| `ftp` | `lftp` |
| `neofetch` | `fastfetch` (system info at a glance) |
| `hex` | `xxd` |
| `b64e` | `base64` |
| `b64d` | `base64 -d` |
| `hashfile` | `sha256sum` |
| `serve` | `python3 -m http.server` (quick HTTP file server on port 8000) |
| `seclists` | Browse the SecLists wordlist directory |

---

## Custom plugins

Two extra plugins are loaded on top of oh-my-zsh (declared in `programs.zsh.plugins`):

| Plugin | What it does |
|---|---|
| `you-should-use` | Reminds you when a command you typed has an existing alias |
| `zsh-autopair` | Auto-inserts matching brackets, quotes, and parentheses |

---

## oh-my-zsh Plugin Commands

### git plugin

Common aliases — for the full list run `alias | grep ^g`.

| Alias | Expands to |
|---|---|
| `gst` | `git status` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gaa` | `git add --all` |
| `gcmsg` | `git commit -m` |
| `glo` | `git log --oneline --decorate` |
| `gd` | `git diff` |
| `gf` | `git fetch` |

### history plugin

| Command | What it does |
|---|---|
| `h` | Full history |
| `hs <term>` | grep history (case-sensitive) |
| `hsi <term>` | grep history (case-insensitive) |

### extract plugin

```bash
x archive.tar.gz      # extract any archive format with one command
x file.zip
x dump.7z
```

### colorize plugin

```bash
ccat exploit.py       # syntax-highlighted cat (via chroma)
cless config.yaml     # syntax-highlighted less
```

### docker plugin

Adds completion for `docker` subcommands and a handful of short aliases
(`dps`, `dpsa`, `dim`, …). Run `alias | grep docker` for the full list.

### nmap plugin

| Alias | Nmap flags |
|---|---|
| `nmap_open_ports` | Quick TCP scan of open ports |
| `nmap_full_udp` | Full UDP scan |
| `nmap_check_for_vulns` | NSE vuln scripts |
| `nmap_full_with_scripts` | All ports + default scripts |
| `nmap_os` | OS detection |

### urltools plugin

```bash
urlencode "hello world & more"    # → hello+world+%26+more
urldecode "hello+world+%26+more"  # → hello world & more
```

### jsontools plugin

```bash
curl -s api/endpoint | pp_json     # pretty-print JSON
echo '{"a":1}' | is_json           # returns 0 if valid JSON
```

### rsync plugin

| Alias | What it does |
|---|---|
| `rsync-copy` | `rsync -avz --progress` |
| `rsync-move` | `rsync -avz --progress --remove-source-files` |

---

## zoxide (directory jumper)

zoxide tracks visited directories and ranks them by frecency.

```bash
z proj          # jump to the most-visited directory matching "proj"
zi              # interactive picker — fzf over your full jump history
z -             # go to the previous directory
```

The `cd` command still works normally. zoxide learns from every `cd` you run.

---

## Startup Banner

Each new terminal session prints the AnNIXion ASCII banner followed by:

- Hostname, current date/time, kernel version
- All global IPv4 addresses — VPN interfaces highlighted in green

The banner is the `annixion-banner` function, defined at the end of `initContent`
in `home/zsh/default.nix` and called once on startup. Run `annixion-banner` to reprint it
in place, or `b` to clear the screen first — useful after a `clear` has scrolled
the addresses away.

To override it per-machine without touching the shared config, use `user/examples/zsh.nix`.
