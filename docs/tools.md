# Enhanced CLI Tools

AnNIXion replaces several standard Unix tools with modern alternatives that are significantly faster, more readable, or purpose-built for security workflows. All of these are declared in `home/` and available immediately after `rebuild`.

---

## bat — cat with syntax highlighting

`bat` is a `cat` replacement with syntax highlighting, line numbers, and git-diff integration. The `cat` alias points to it automatically.

```bash
cat exploit.py          # syntax-highlighted Python
cat config.json         # highlighted JSON with line numbers
cat -A binary           # show non-printable characters

# Explicit bat features
bat --style=plain file  # no decorations (just highlighting)
bat -l yaml file        # force a specific language
bat -r 10:30 file       # show lines 10–30
bat -d file1 file2      # diff two files with highlighting
```

**In pipelines**, bat detects that stdout is not a terminal and falls back to plain output automatically — `cat file | grep pattern` still works.

To force pager output in a pipeline: `bat --paging=always file`.

---

## ripgrep (rg) — fast recursive grep

`rg` is a modern grep that respects `.gitignore`, skips binary files by default, and is typically 5–10× faster than `grep -r`.

```bash
rg "password"                    # recursive search in current dir
rg -i "admin" /etc/              # case-insensitive
rg -t py "import os"             # only in Python files
rg -t json "api_key"             # only in JSON files
rg -l "TODO"                     # list matching files, not lines
rg -c "error" logs/              # count matches per file
rg -A 3 -B 3 "exception"         # 3 lines before and after
rg "https?://\S+" --only-matching  # extract URLs from all files
rg "Bearer [A-Za-z0-9._-]+"     # extract bearer tokens
```

**Tip:** `rg` is significantly faster than `grep -r` for codebase or log searches. Use it as your default recursive search.

---

## fd — fast find

`fd` is a user-friendly alternative to `find`. It respects `.gitignore`, uses sensible defaults, and has cleaner syntax.

```bash
fd passwd /etc            # find files named "passwd" in /etc
fd -e php                 # find all PHP files recursively
fd -e log -x rm {}        # find and delete all .log files
fd -t d vendor            # find directories named "vendor"
fd -H .env                # include hidden files in search
fd --changed-within 1d    # files modified in the last day
fd -e sh -x chmod +x {}   # make all shell scripts executable
```

**With fzf** — pipe fd into fzf for interactive selection:
```bash
fd -e conf | fzf           # pick a config file interactively
fd -t f | fzf | xargs bat  # browse and preview any file
```

---

## fzf — fuzzy finder

`fzf` is a general-purpose interactive fuzzy filter. Key bindings are wired into ZSH automatically.

### ZSH key bindings

| Key | What it does |
|---|---|
| `Ctrl+R` | Fuzzy search through command history with live preview |
| `Ctrl+T` | Fuzzy file picker — inserts selected path at cursor |
| `Alt+C` | Fuzzy cd into any subdirectory |
| `Tab` | **fzf-tab** — turns any completion into a fzf popup |

### In pipelines

```bash
ps aux | fzf                    # pick a process interactively
cat /etc/passwd | fzf           # search through passwd entries
cat hosts.txt | fzf             # interactive host selection
ls /var/log/*.log | fzf | xargs tail -f   # pick a log to tail
```

### Kill a process interactively

```bash
kill -9 $(ps aux | fzf | awk '{print $2}')
```

### Multi-select with `-m`

```bash
cat urls.txt | fzf -m           # select multiple URLs with Tab
fd -e py | fzf -m | xargs bat   # preview multiple scripts
```

### Preview window

```bash
fzf --preview 'bat --color=always {}'   # preview files with bat
fzf --preview 'cat {}'                  # simpler preview
```

---

## jq — JSON processor

`jq` is a command-line JSON processor. Indispensable for parsing API responses, config files, and tool output during engagements.

```bash
# Pretty-print
curl -s api/endpoint | jq .

# Extract a field
curl -s api/users | jq '.[0].email'

# Filter array
jq '.[] | select(.role == "admin")' users.json

# Extract all keys
jq 'keys' config.json

# Multiple fields
jq '{id: .id, name: .name}' data.json

# Compact output (no whitespace) — useful in pipelines
jq -c '.[] | .token' tokens.json

# Raw string output (no quotes) — useful for shell use
curl -s api | jq -r '.access_token'
```

---

## zoxide — smart directory jumping

`zoxide` tracks directories by frecency (frequency + recency) and lets you jump to them by partial name.

```bash
z proj               # jump to the highest-ranked directory matching "proj"
z dot conf           # jump using multiple terms (must match in order)
zi                   # interactive fzf picker over full jump history
z -                  # go to the previous directory
```

**Builds up over time** — the more you use a directory, the higher it ranks. On a fresh install, use `cd` normally; zoxide learns your habits passively.

---

## xxd — hex viewer

```bash
hex file.bin             # (alias for xxd) — full hex dump
xxd file.bin | less      # paginate large files
xxd -l 64 file.bin       # first 64 bytes only
xxd -s 0x100 file.bin    # start at offset 0x100
xxd -p file.bin          # plain hex, no addresses or ASCII
xxd -r hex_dump > out    # reverse: hex back to binary
```

---

## base64 encoding/decoding

```bash
b64e <<< "admin:password"              # encode string
echo -n "secret" | b64e               # encode without newline
echo "YWRtaW46cGFzc3dvcmQ=" | b64d   # decode
b64d < encoded_file > decoded_file    # decode a file
```

---

## Quick HTTP server

```bash
serve                    # (alias) python3 -m http.server — port 8000
python3 -m http.server 9090   # custom port
python3 -m http.server 8080 --bind 0.0.0.0   # bind all interfaces
```

Useful for transferring files to/from targets without a dedicated file server.

---

## lftp — advanced FTP/SFTP client

```bash
ftp                      # (alias for lftp)

lftp ftp://target.com
lftp -u user,pass sftp://host
mirror /remote/path ./local/   # download entire directory tree
mirror -R ./local/ /remote/    # upload entire directory tree
```

---

## SecLists browser

```bash
seclists     # list top-level SecLists categories in the Nix store
```

SecLists is installed system-wide at `/run/current-system/sw/share/wordlists/seclists/`. Point tools directly at that path:

```bash
gobuster dir -u http://target -w /run/current-system/sw/share/wordlists/seclists/Discovery/Web-Content/common.txt
ffuf -u http://target/FUZZ -w /run/current-system/sw/share/wordlists/seclists/Discovery/Web-Content/big.txt
hydra -L /run/current-system/sw/share/wordlists/seclists/Usernames/top-usernames-shortlist.txt ...
```

Set `SECLISTS_PATH` in your environment to override the default path for the `seclists` alias.

---

## Docker — containers and images

The daemon is rootless: it runs as you, and `DOCKER_HOST` already points at your
own socket. Nothing needs `sudo`, and there is no `docker` group to join. What
that costs, and how to switch to a rootful daemon when a container needs the
host network or a raw socket, is in [hardening.md](hardening.md#docker).

```bash
docker ps                        # your containers, not root's
docker compose up -d             # v2 plugin, shipped with the CLI
docker-compose up -d             # standalone v2, same thing
docker buildx build .            # also a shipped plugin
```

### lazydocker — TUI over everything running

```bash
lazydocker
```

Containers, images, volumes and live logs in one screen. Faster than
`docker ps` + `docker logs -f` when you are watching a lab come up.

### dive — read an image layer by layer

```bash
dive nginx:latest                # explore a pulled image
dive <image-id>
```

Shows what each layer added and what it wasted. The reason to reach for it on
this machine is inspection: it is how you find the key, the `.env` or the source
tree someone baked into a published image.

### ctop — live per-container metrics

```bash
ctop
```

CPU, memory, network and disk per container, sorted live. Useful for spotting
which container in a compose stack is the one actually doing work.

### skopeo — registries without pulling

```bash
skopeo inspect docker://nginx:latest            # manifest, no download
skopeo list-tags docker://registry/image        # enumerate tags
skopeo copy docker://img oci-archive:img.tar    # pull to a file
```

No daemon involved, so it works against a registry you have only credentials
for. Reading tags and manifests before pulling gigabytes is the recon case.

### trivy — scan an image for known-vulnerable packages

```bash
trivy image nginx:latest                        # CVEs by package
trivy image --severity HIGH,CRITICAL <image>
trivy fs .                                      # a source tree instead
```

Reports the CVEs in an image's packages, and `trivy fs` does the same for a
checkout. It reads package manifests — it finds published vulnerabilities in
known components, not a backdoor someone wrote by hand.
