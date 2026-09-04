<div align="center">

# AnNIXion

![AnNIXion banner](assets/branding/banner.png)

**The environment for operators who refuse to wing it.**

[![Version](https://img.shields.io/github/v/release/Pyth3rEx/AnNIXion?style=flat-square&label=version&color=2EA043&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAWCAMAAACWh252AAAAnFBMVEX///+9vb2+trbNyMjt7Oy3trZoFBRzHh7JyMjHv79qCgpfCAipmpppZ2eZkZGRgICXioq7urq9vLzx8fH29vbn5ubVyclQCgqNcXGGbW14VFSZamq4mppTCQlgGBh6QECIVFR4MDBmGRnYyMjBpKRuEBCreXmBLCxlBwdvJyeNYWFzPj6BRUV8LS3m399hEBBsCQmKFRXy8PCiiIhhszV1AAAAAXRSTlMAQObYZgAAASZJREFUKM9tko12gjAMhUspMxZoLZa5ISqCf6CI4vu/20rwAEO+c6BA0nBvUkIQizZ3mzlfM5jPOOeuy8kQz8dFCCIXgkygAixBGQBTUwkSQOLDUocT4QAM8yCgUobs+zO++vF/ET+K1nG02WyjLUpc9Tm7JNmn2zRN19lhf0xOZ3dUxMnopWV2iPPFouCrhl7jQJqS1+g29pBlQ2/leRi0GWP6fsorQ9u8x/N5fFTVIKHWdZx3H3jVMihimkPVSPbFXF0O08oKil7kqAVE6SWhQN9vFF4fnaxxFq+82VUIUZRlyTvQZVMGHGX8MEcik+OkUNc6XDIQu4mBWgAWCrKnxt38wRMeFg7tsQkEoLh5XmFOItXs6rqYYKbVnczm0L6tCvpv6x9FEReRd286IAAAAABJRU5ErkJggg==)](https://github.com/Pyth3rEx/AnNIXion/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Pyth3rEx/AnNIXion/total?style=flat-square&color=2EA043&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/releases)
[![Stars](https://img.shields.io/github/stars/Pyth3rEx/AnNIXion?style=flat-square&color=E3B341&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/stargazers)
[![CI](https://img.shields.io/github/actions/workflow/status/Pyth3rEx/AnNIXion/ci.yml?style=flat-square&label=CI&logo=githubactions&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=gnu&logoColor=white)](LICENSE)
<br>
[![NixOS](https://img.shields.io/badge/NixOS-26.05-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Flakes](https://img.shields.io/badge/flakes-enabled-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-5277C3?style=flat-square&logo=linux&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion)
<br>
[![Last commit](https://img.shields.io/github/last-commit/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/commits/main)
[![Commit activity](https://img.shields.io/github/commit-activity/m/Pyth3rEx/AnNIXion?style=flat-square&color=4A4A4A&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/graphs/commit-activity)
[![Issues](https://img.shields.io/github/issues/Pyth3rEx/AnNIXion?style=flat-square&color=D29922&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/issues)
[![Pull requests](https://img.shields.io/github/issues-pr/Pyth3rEx/AnNIXion?style=flat-square&color=8957E5&logo=github&logoColor=white)](https://github.com/Pyth3rEx/AnNIXion/pulls)

[**Installation**](docs/installation.md) · [**Usage**](docs/usage.md) · [**Customization**](docs/customization.md) · [**Roadmap**](docs/roadmap.md)

</div>

---

AnNIXion is a NixOS-based offensive security distribution for red teamers, OSINT
practitioners and persona operators. Every tool, browser profile, proxy rule and
desktop shortcut is declared in code — version-controlled, reproducible, deployed
in a single command.

The name comes from *annexion* — to take full control of a territory, absorb it
completely, make it yours.

---

## Quick start

**Fresh install — no NixOS required:**

1. Download the latest ISO from [Releases](https://github.com/Pyth3rEx/AnNIXion/releases/latest)
2. Flash to USB with [Rufus](https://rufus.ie) (Windows) or `dd` (Linux/macOS)
3. Boot — it auto-logs in as `operator`
4. Connect with `nmtui`, then run `annixion-install`

**On existing NixOS:**

```bash
git clone https://github.com/Pyth3rEx/AnNIXion ~/.dotfiles
cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/
git -C ~/.dotfiles add hardware-configuration.nix -f
sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion --impure
```

After the first build, `rebuild`, `upgrade` and `update` are available from the
shell. Full guide, including Hyper-V Enhanced Session:
[docs/installation.md](docs/installation.md).

---

## What makes it different

- **The killswitch is in the kernel, not the browser.** OSINT and Puppet Master
  run in a systemd slice, and an nftables rule on that cgroup permits egress only
  through a live tunnel — so WebRTC, OCSP and captive-portal probes are covered
  too, and traffic stops if the tunnel drops.
- **Four Firefox profiles that cannot bleed into each other.** Separate cookies,
  cache, extensions and egress path, generated from configuration. Burp's CA is
  fetched and trusted on first install.
- **One flake, one command.** Redeploying is the same command as deploying, and
  a bad change is undone by booting the previous generation.
- **A tool is one file.** Its package, menu entry and icon live together in
  [`catalog/`](catalog/), so they cannot drift apart.

---

## Documentation

| | |
|---|---|
| [Installation](docs/installation.md) | Prerequisites, deploy steps, Hyper-V setup |
| [Architecture](docs/architecture.md) | How the tree is laid out, and how to add a tool |
| [Usage](docs/usage.md) | Commands, browser profiles, Burp and VPN setup |
| [Customization](docs/customization.md) | The user override system, adding tools, dev environment |
| [Shell reference](docs/zsh.md) | Prompt, keybindings, aliases and plugins |
| [CLI tools](docs/tools.md) | The enhanced command-line toolset |
| [Hardening](docs/hardening.md) | What is disabled to reduce attack surface, and how to restore it |
| [Visual identity](docs/visual-identity.md) | Palette, typography, the mark system |
| [Developer guide](docs/dev.md) · [Testing](docs/testing.md) | Local CI levels · the suite and the rule behind it |
| [FAQ](docs/faq.md) · [Roadmap](docs/roadmap.md) | Troubleshooting · phase-by-phase progress |
| [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) | How to contribute · posture and reporting |

---

## Status

Active development, deployable today. Shipping **0.3.1 "Tripwire"**; next is
**0.4.0 "Nebula"**. Full disk encryption, a TUI installer and kernel hardening
are the notable gaps — see [docs/roadmap.md](docs/roadmap.md).

---

<div align="center">

**For authorized security testing, research and educational use only.**
Obtain explicit written permission before any assessment. The authors assume no
liability for misuse.

</div>
