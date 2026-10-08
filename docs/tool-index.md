# Tool index

Everything AnNIXion puts on the machine, in one line each, with a link to the
tool's own manual rather than to a summary of it.

Three pages cover the toolset and they are not the same page:

| Page | What it is for |
|---|---|
| **This one** | Finding out what is installed and where its documentation is |
| [Enhanced CLI tools](tools.md) | Learning the handful of CLI replacements properly, with worked examples |
| [Installed applications](security/apps.md) | The generated bill of materials — every declared package including libraries, with versions, licences and CVE counts |

The first is curated and written by hand. The third is generated weekly and is
the one to cite; this page will drift from it between releases, and where they
disagree, the generated page is right.

---

## How to read this page

The offensive tables carry a **class** — the same semantic colour the menu
draws the tool's icon in. It says what running the tool does to a target, not
which phase it sits in:

| Class | Means |
|---|---|
| passive | Sends nothing to the target |
| probe | Touches the target and shows up in their logs, no access attempted |
| offensive | Attempts access, execution or credential compromise |
| forensic | Reads evidence after the fact, never reaches the network |
| reverse | Pulls a compiled artifact apart |
| utility | Not a tool of the trade |

**Offensive-class tools need written authorisation behind them.** That is the
one place the colour is a check on muscle memory rather than decoration. The
full scheme is in [visual identity](visual-identity.md#semantic-classes).

Tools in the first three tables are declared one file each under `catalog/`,
which is also what builds their menu entry and icon — see
[architecture](architecture.md). Everything below that is declared in `system/`
or `home/`.

---

## 01. Reconnaissance

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [theHarvester](https://github.com/laramies/theHarvester#readme) | passive | Email, subdomain and IP intelligence from public sources | [README](https://github.com/laramies/theHarvester#readme) |
| [Whois](https://manpages.debian.org/stable/whois/whois.1.en.html) | passive | Domain and netblock registration lookup | [whois(1)](https://manpages.debian.org/stable/whois/whois.1.en.html) |
| [dig](https://bind9.readthedocs.io/en/latest/manpages.html) | passive | DNS lookup, from the BIND utilities | [BIND manpages](https://bind9.readthedocs.io/en/latest/manpages.html) |
| [SecLists](https://github.com/danielmiessler/SecLists#readme) | passive | Wordlists for discovery, fuzzing and credential attacks | [README](https://github.com/danielmiessler/SecLists#readme) |
| [Nmap](https://nmap.org/book/man.html) | probe | Host discovery, port scanning, service and OS fingerprinting | [Reference Guide](https://nmap.org/book/man.html) |
| [WhatWeb](https://github.com/urbanadventurer/WhatWeb/wiki) | probe | Web server and technology fingerprinting | [Wiki](https://github.com/urbanadventurer/WhatWeb/wiki) |
| [Gobuster](https://github.com/OJ/gobuster#readme) | probe | Brute-forces directories, DNS names and virtual hosts | [README](https://github.com/OJ/gobuster#readme) |
| [ffuf](https://github.com/ffuf/ffuf/wiki) | probe | Fast web fuzzer for paths, parameters and headers | [Wiki](https://github.com/ffuf/ffuf/wiki) |
| [HackRF Tools](https://hackrf.readthedocs.io/) | probe | Command-line interface and diagnostics for HackRF radios | [Docs](https://hackrf.readthedocs.io/) |
| [Gqrx](https://gqrx.dk/doc) | probe | Software-defined radio receiver with a waterfall display | [Docs](https://gqrx.dk/doc) |
| [GNU Radio Companion](https://www.gnuradio.org/) | probe | Flow-graph signal processing toolkit for SDR | [Project site](https://www.gnuradio.org/) · [wiki](https://wiki.gnuradio.org/) |

`seclists` is a real command, not an alias — it opens the wordlist tree in the
file manager.

---

## 02. Weaponization · 09. Reverse Engineering

Both phases open the same two tools; the menu lists them twice on purpose.

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [Ghidra](https://github.com/NationalSecurityAgency/ghidra/wiki) | reverse | Disassembler and decompiler suite, originally the NSA's | [Wiki](https://github.com/NationalSecurityAgency/ghidra/wiki) |
| [Binwalk](https://github.com/ReFirmLabs/binwalk/wiki) | reverse | Finds and extracts embedded files inside firmware images | [Wiki](https://github.com/ReFirmLabs/binwalk/wiki) |

---

## 03. Delivery

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [Burp Suite](https://portswigger.net/burp/documentation) | offensive | Intercepting web proxy, scanner and repeater | [Documentation](https://portswigger.net/burp/documentation) |
| [sqlmap](https://github.com/sqlmapproject/sqlmap/wiki) | offensive | Automated SQL injection detection and database takeover | [Wiki](https://github.com/sqlmapproject/sqlmap/wiki) |

Burp's CA is installed into the Firefox profiles by `annixion-burp-ca`; see
[usage](usage.md).

---

## 04. Exploitation

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [Metasploit](https://docs.metasploit.com/) | offensive | Exploitation framework, payload generation and Meterpreter | [Docs](https://docs.metasploit.com/) |
| [Hydra](https://github.com/vanhauser-thc/thc-hydra#readme) | offensive | Online brute-forcing against network login services | [README](https://github.com/vanhauser-thc/thc-hydra#readme) |
| [John the Ripper](https://www.openwall.com/john/doc/) | offensive | Offline password hash cracking | [Docs](https://www.openwall.com/john/doc/) |
| [Hashcat](https://hashcat.net/wiki/) | offensive | GPU-accelerated password recovery | [Wiki](https://hashcat.net/wiki/) |
| [Aircrack-ng](https://www.aircrack-ng.org/documentation.html) | offensive | 802.11 capture and WEP/WPA key recovery | [Documentation](https://www.aircrack-ng.org/documentation.html) |

---

## 05. Installation · 10. Sniffing & Analysis

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [Netcat](https://netcat.sourceforge.net/) | offensive | Raw TCP/UDP listeners, pivots and file transfer | [GNU netcat](https://netcat.sourceforge.net/) |
| [Wireshark](https://www.wireshark.org/docs/) | forensic | Packet capture and protocol analysis | [Docs](https://www.wireshark.org/docs/) |

---

## 06. Command & Control

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [AdaptixC2](https://adaptix-framework.gitbook.io/) | offensive | Extensible C2 — dockerised teamserver, native Qt operator client | [Docs](https://adaptix-framework.gitbook.io/) |
| [Metasploit](https://docs.metasploit.com/) | offensive | Also serves as C2 via Meterpreter | [Docs](https://docs.metasploit.com/) |

Building and running the AdaptixC2 teamserver on AnNIXion is covered in
[adaptixc2.md](adaptixc2.md).

---

## 07. Post-Exploitation

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [Impacket](https://github.com/fortra/impacket) | offensive | Python implementations of Windows protocols — SMB, Kerberos, DCE/RPC | [Repository](https://github.com/fortra/impacket) |

Each script is on `PATH` as `impacket-<tool>`, so `impacket-<Tab>` lists them.

---

## 08. Forensics

| Tool | Class | What it is | Manual |
|---|---|---|---|
| [Volatility 3](https://volatility3.readthedocs.io/) | forensic | Memory image analysis — processes, injection, network state | [Docs](https://volatility3.readthedocs.io/) |
| [Autopsy](https://sleuthkit.org/autopsy/docs.php) | forensic | Disk forensics interface over The Sleuth Kit | [Docs](https://sleuthkit.org/autopsy/docs.php) |

---

## Browsers

Four Firefox profiles, each with its own cookies, extensions and route out of
the machine. Launching and proxy behaviour is in [usage](usage.md).

| Profile | Class | Route out | Manual |
|---|---|---|---|
| Red Team | offensive | Burp at `127.0.0.1:8080`, fails closed | [Firefox help](https://support.mozilla.org/en-US/products/firefox) |
| OSINT | probe | VPN tunnel, kernel-enforced | [Firefox help](https://support.mozilla.org/en-US/products/firefox) |
| Puppet Master | passive | VPN tunnel, kernel-enforced | [Firefox help](https://support.mozilla.org/en-US/products/firefox) |
| Unsafe Browser | utility | Direct, no proxy | [Firefox help](https://support.mozilla.org/en-US/products/firefox) |

---

## Desktop applications

| Tool | What it is | Manual |
|---|---|---|
| [Konsole](https://docs.kde.org/?application=konsole) | Terminal emulator; separate root and Nix-shell entries | [Handbook](https://docs.kde.org/?application=konsole) |
| [Dolphin](https://docs.kde.org/?application=dolphin) | File manager | [Handbook](https://docs.kde.org/?application=dolphin) |
| [Kate](https://docs.kde.org/?application=kate) | Text editor | [Handbook](https://docs.kde.org/?application=kate) |
| [Ark](https://docs.kde.org/?application=ark) | Archive manager | [Handbook](https://docs.kde.org/?application=ark) |
| [KCalc](https://docs.kde.org/?application=kcalc) | Calculator | [Handbook](https://docs.kde.org/?application=kcalc) |
| [Filelight](https://docs.kde.org/?application=filelight) | Disk usage, drawn as concentric rings | [Handbook](https://docs.kde.org/?application=filelight) |
| [KWallet Manager](https://docs.kde.org/?application=kwalletmanager) | Credential store, unlocked at login | [Handbook](https://docs.kde.org/?application=kwalletmanager) |
| [Kleopatra](https://docs.kde.org/?application=kleopatra) | OpenPGP and X.509 certificate management | [Handbook](https://docs.kde.org/?application=kleopatra) |
| [System Settings](https://userbase.kde.org/System_Settings) | Plasma configuration | [UserBase](https://userbase.kde.org/System_Settings) |
| [VSCodium](https://code.visualstudio.com/docs) | Code editor, telemetry-free VS Code build | [VS Code docs](https://code.visualstudio.com/docs) |
| [GitHub Desktop](https://docs.github.com/en/desktop) | Git GUI | [Docs](https://docs.github.com/en/desktop) |
| [Obsidian](https://help.obsidian.md/) | Markdown notes over a local folder — engagement notes | [Help](https://help.obsidian.md/) |
| [OnlyOffice](https://helpcenter.onlyoffice.com/) | Documents, spreadsheets and presentations | [Help centre](https://helpcenter.onlyoffice.com/) |
| [Glow](https://github.com/charmbracelet/glow#readme) | Renders Markdown in the terminal; the `text/markdown` handler | [README](https://github.com/charmbracelet/glow#readme) |
| [htop](https://htop.dev/) | Interactive process viewer | [Site](https://htop.dev/) |

---

## Shell and CLI

The shell stack is documented in full in [zsh.md](zsh.md); the five marked ★
get worked examples in [tools.md](tools.md).

| Tool | What it is | Manual |
|---|---|---|
| [zsh](https://zsh.sourceforge.io/Doc/) | The login shell for every user, root included | [Manual](https://zsh.sourceforge.io/Doc/) |
| [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh/wiki) | Plugin framework — git, docker, extract, sudo and more | [Wiki](https://github.com/ohmyzsh/ohmyzsh/wiki) |
| [oh-my-posh](https://ohmyposh.dev/docs) | The prompt, on the AnNIXion chrome palette | [Docs](https://ohmyposh.dev/docs) |
| ★ [bat](https://github.com/sharkdp/bat#readme) | `cat` with syntax highlighting; aliased over `cat` | [README](https://github.com/sharkdp/bat#readme) |
| ★ [ripgrep](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md) | Recursive search that respects `.gitignore` | [Guide](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md) |
| ★ [fd](https://github.com/sharkdp/fd#readme) | `find` with sensible defaults | [README](https://github.com/sharkdp/fd#readme) |
| ★ [fzf](https://github.com/junegunn/fzf#readme) | Fuzzy finder, bound to `Ctrl+R` and `Ctrl+T` | [README](https://github.com/junegunn/fzf#readme) |
| ★ [jq](https://jqlang.github.io/jq/manual/) | JSON query and transform | [Manual](https://jqlang.github.io/jq/manual/) |
| [zoxide](https://github.com/ajeetdsouza/zoxide#readme) | Directory jumping that learns where you go | [README](https://github.com/ajeetdsouza/zoxide#readme) |
| [curl](https://curl.se/docs/manual.html) | HTTP and everything-else client | [Manual](https://curl.se/docs/manual.html) |
| [wget](https://www.gnu.org/software/wget/manual/) | Recursive and resumable downloads | [Manual](https://www.gnu.org/software/wget/manual/) |
| [lftp](https://lftp.yar.ru/lftp-man.html) | Scriptable FTP/SFTP/HTTP client; the `ftp` alias | [lftp(1)](https://lftp.yar.ru/lftp-man.html) |
| [inetutils](https://www.gnu.org/software/inetutils/manual/) | telnet, ftp, traceroute and the classic network clients | [Manual](https://www.gnu.org/software/inetutils/manual/) |
| [net-tools](https://github.com/ecki/net-tools) | ifconfig, netstat, route — the older interface | [Project](https://github.com/ecki/net-tools) |
| [wireless-tools](https://hewlettpackard.github.io/wireless-tools/Tools.html) | iwconfig, iwlist and the pre-`iw` wireless interface | [Tools](https://hewlettpackard.github.io/wireless-tools/Tools.html) |
| [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) | Lightweight DNS and DHCP, for lab and relay work | [Docs](https://thekelleys.org.uk/dnsmasq/doc.html) |
| [tree](https://manpages.debian.org/stable/tree/tree.1.en.html) | Directory listing as a tree | [tree(1)](https://manpages.debian.org/stable/tree/tree.1.en.html) |
| [file](https://www.darwinsys.com/file/) | Identifies a file by content, not extension | [Site](https://www.darwinsys.com/file/) |
| [unzip](https://manpages.debian.org/stable/unzip/unzip.1.en.html) | Zip extraction | [unzip(1)](https://manpages.debian.org/stable/unzip/unzip.1.en.html) |
| [p7zip](https://7-zip.org/) | 7z and most other archive formats | [7-Zip](https://7-zip.org/) |
| [chroma](https://github.com/alecthomas/chroma#readme) | Syntax highlighter behind the oh-my-zsh colorize plugin | [README](https://github.com/alecthomas/chroma#readme) |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch#readme) | The system summary at shell start; `neofetch` is aliased to it | [README](https://github.com/fastfetch-cli/fastfetch#readme) |
| [git](https://git-scm.com/docs) | Version control | [Reference](https://git-scm.com/docs) |
| [GitHub CLI](https://cli.github.com/manual/) | `gh` — pull requests, issues and releases from the shell | [Manual](https://cli.github.com/manual/) |
| [act](https://nektosact.com/) | Runs GitHub Actions workflows locally | [Docs](https://nektosact.com/) |
| [any-nix-shell](https://github.com/haslersn/any-nix-shell#readme) | Keeps zsh as the shell inside `nix-shell` | [README](https://github.com/haslersn/any-nix-shell#readme) |
| [Python 3](https://www.python.org/doc/) | Interpreter plus `pip`; the `serve` alias runs `http.server` | [Docs](https://www.python.org/doc/) |

---

## C/C++ toolchain

The default compiler is LLVM, not GCC — `CC`/`CXX` are set in
`system/toolchain.nix`. Rationale and the VSCodium wiring are in
[customization](customization.md).

| Tool | What it is | Manual |
|---|---|---|
| [Clang](https://clang.llvm.org/docs/) | The default C/C++ compiler | [Docs](https://clang.llvm.org/docs/) |
| [LLVM](https://llvm.org/docs/) | The toolchain underneath it | [Docs](https://llvm.org/docs/) |
| [clang-tools](https://clangd.llvm.org/) | clangd, clang-tidy and clang-format | [clangd](https://clangd.llvm.org/) |
| [LLDB](https://lldb.llvm.org/) | The LLVM debugger | [Docs](https://lldb.llvm.org/) |
| [GDB](https://sourceware.org/gdb/current/onlinedocs/gdb/) | The GNU debugger, for what LLDB will not take | [Manual](https://sourceware.org/gdb/current/onlinedocs/gdb/) |
| [CMake](https://cmake.org/documentation/) | Build system generator | [Docs](https://cmake.org/documentation/) |
| [Ninja](https://ninja-build.org/manual.html) | Fast build backend | [Manual](https://ninja-build.org/manual.html) |
| [GNU Make](https://www.gnu.org/software/make/manual/) | The older build driver | [Manual](https://www.gnu.org/software/make/manual/) |
| [Bear](https://github.com/rizsotto/Bear#readme) | Produces `compile_commands.json` so clangd sees the build | [README](https://github.com/rizsotto/Bear#readme) |
| [ShellCheck](https://www.shellcheck.net/wiki/) | Static analysis for shell scripts; CI runs it | [Wiki](https://www.shellcheck.net/wiki/) |
| [OpenSSL](https://docs.openssl.org/) | TLS library and the `openssl` command | [Docs](https://docs.openssl.org/) |

---

## Containers

Docker runs **rootless**, as your user, with no `docker` group — that group is
root by another name. See [hardening](hardening.md).

| Tool | What it is | Manual |
|---|---|---|
| [Docker](https://docs.docker.com/) | The container runtime and CLI | [Docs](https://docs.docker.com/) |
| [docker-compose](https://docs.docker.com/compose/) | Multi-container definitions | [Docs](https://docs.docker.com/compose/) |
| [lazydocker](https://github.com/jesseduffield/lazydocker#readme) | Terminal UI over containers, logs and images | [README](https://github.com/jesseduffield/lazydocker#readme) |
| [dive](https://github.com/wagoodman/dive#readme) | Walks an image layer by layer | [README](https://github.com/wagoodman/dive#readme) |
| [ctop](https://github.com/bcicen/ctop#readme) | Live per-container resource metrics | [README](https://github.com/bcicen/ctop#readme) |
| [skopeo](https://github.com/containers/skopeo/blob/main/docs/skopeo.1.md) | Inspects and copies registry images without a daemon | [skopeo(1)](https://github.com/containers/skopeo/blob/main/docs/skopeo.1.md) |
| [trivy](https://trivy.dev/latest/docs/) | Scans images for known-vulnerable packages | [Docs](https://trivy.dev/latest/docs/) |

---

## Network and VPN

| Tool | What it is | Manual |
|---|---|---|
| [NetworkManager](https://networkmanager.dev/docs/) | Connection management; `nmtui` is the text interface | [Docs](https://networkmanager.dev/docs/) |
| [WireGuard tools](https://www.wireguard.com/quickstart/) | `wg` and `wg-quick` | [Quick start](https://www.wireguard.com/quickstart/) |
| [OpenVPN](https://openvpn.net/community-resources/) | The other tunnel type the killswitch recognises | [Community docs](https://openvpn.net/community-resources/) |

Egress enforcement is a cgroup and an nftables rule rather than anything these
three do; [usage](usage.md) covers the model and the failure behaviour.

---

## AnNIXion's own commands

Written in this repository, not packaged from elsewhere. `annixion-<Tab>` lists
them. Full descriptions and worked examples are in [usage](usage.md).

| Command | What it does |
|---|---|
| `annixion-install` | Installs to disk from the live ISO |
| `annixion-cc` | Control centre — Wi-Fi, Bluetooth, network killswitch |
| `annixion-burp-ca` | Fetches Burp's CA so the Firefox profiles trust intercepted HTTPS |
| `annixion-vpn-run` | Runs any command inside the VPN-enforced slice |
| `annixion-vpn-browser` | Launches a Firefox profile inside that slice |
| `annixion-vpn-status` | Tunnel, killswitch and slice state |
| `annixion-vpn-tunnels` | Lists every interface that qualifies as a live tunnel |
| `annixion-vpn-detect` | Prints the first live tunnel, or exits 1 |
| `annixion-vpn-killswitch-load` | Arms the nftables killswitch (needs root) |
| `annixion-raise` | Focuses a running window by `WM_CLASS`, or launches the app |
| `annixion-cve-report` | Regenerates the weekly CVE pipeline against your own checkout |
| `seclists` | Opens the wordlist tree in the file manager |

Importing the Hack The Box example from `user/examples/` adds
`annixion-htb-hosts` and `annixion-htb-vpn`.

---

## The dev shell

`nix develop` drops you into the shell CI uses. Not installed system-wide — it
exists only inside that shell. See [dev.md](dev.md).

| Tool | What it is | Manual |
|---|---|---|
| [nixfmt](https://github.com/NixOS/nixfmt#readme) | The Nix formatter; L0 lint enforces it | [README](https://github.com/NixOS/nixfmt#readme) |
| [statix](https://github.com/oppiliappan/statix#readme) | Lints Nix for antipatterns | [README](https://github.com/oppiliappan/statix#readme) |
| [deadnix](https://github.com/astro/deadnix#readme) | Finds unused Nix bindings | [README](https://github.com/astro/deadnix#readme) |
| [nil](https://github.com/oxalica/nil#readme) | Nix language server | [README](https://github.com/oxalica/nil#readme) |
| [nix-output-monitor](https://github.com/maralorn/nix-output-monitor#readme) | Readable build output | [README](https://github.com/maralorn/nix-output-monitor#readme) |
| [sbomnix](https://github.com/tiiuae/sbomnix#readme) | Builds the release SBOMs and wraps the vulnerability scanners | [README](https://github.com/tiiuae/sbomnix#readme) |
| [yq-go](https://mikefarah.gitbook.io/yq) | YAML query; the workflow tests read `run:` blocks with it | [Docs](https://mikefarah.gitbook.io/yq) |

`jq`, `oh-my-posh`, `python3`, `shellcheck` and `dnsutils` are in the dev shell
too, pinned there so a check run does not depend on what happens to be on the
host. They are described above.

---

## Adding a tool

A tool is one file under `catalog/`, and the package, the menu entry, the
category and the icon all derive from it — nothing registers it anywhere else.
[Architecture](architecture.md) has the walkthrough. Add it to this page in the
same change; nothing generates this file.
