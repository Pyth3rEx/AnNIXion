#!/usr/bin/env bash
# The boot splash, the greeter and the installer image are the three surfaces
# a user meets before the desktop exists, and all three fail quietly: Plymouth
# falls back to a black screen, SDDM to stock Breeze, the ISO to NixOS artwork.
# Nothing errors, so nothing tells you the branding stopped being applied.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYS='.#nixosConfigurations.AnNIXion-ci.config'
ISO='.#nixosConfigurations.AnNIXion-iso.config'
fails=0

report() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" -eq 0 ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s: %s\n' "$name" "$detail"
    fails=$((fails + 1))
  fi
}

# Width and height straight out of the PNG header.
png_size() {
  python3 - "$1" <<'EOF'
import struct, sys
d = open(sys.argv[1], 'rb').read(24)
print("%dx%d" % struct.unpack('>II', d[16:24]) if d[:8] == b'\x89PNG\r\n\x1a\n' else "notpng")
EOF
}

cd "$ROOT" || exit 1

# ── Boot splash ────────────────────────────────────────────────────────────
theme=$(nix eval --raw "$SYS.boot.plymouth.theme" 2>/dev/null)
report "$([ "$theme" = "annixion" ] && echo 0 || echo 1)" \
  "the system boots the AnNIXion splash" "plymouth theme is ${theme:-<unset>}"

# The module copies the selected theme into the initrd. If the name and the
# package ever disagree this derivation is what fails.
initrd=$(nix build --no-link --print-out-paths \
  "$SYS.boot.initrd.systemd.contents.\"/etc/plymouth/themes\".source" 2>/dev/null)
report "$([ -n "$initrd" ] && echo 0 || echo 1)" \
  "the splash theme reaches the initrd" "theme tree did not build"

if [ -n "$initrd" ]; then
  for f in annixion.plymouth annixion.script logo.png bar.png bar-bg.png; do
    report "$([ -f "$initrd/$theme/$f" ] && echo 0 || echo 1)" \
      "the splash ships $f" "missing from $initrd/$theme"
  done

  # A script theme is inert without its plugin, and the failure is a black
  # screen rather than an error.
  module=$(sed -n 's/^ModuleName *= *//p' "$initrd/$theme/$theme.plymouth" 2>/dev/null)
  plugins=$(nix build --no-link --print-out-paths \
    "$SYS.boot.initrd.systemd.contents.\"/etc/plymouth/plugins\".source" 2>/dev/null)
  report "$([ -n "$module" ] && [ -f "$plugins/$module.so" ] && echo 0 || echo 1)" \
    "the splash's $module plugin is in the initrd" \
    "ModuleName=${module:-<unset>} has no matching .so"
fi

# A splash you cannot interrupt is a machine with no way back to an older
# generation.
timeout=$(nix eval "$SYS.boot.loader.timeout" 2>/dev/null)
report "$([ "${timeout:-0}" -ge 1 ] 2>/dev/null && echo 0 || echo 1)" \
  "the boot menu stays reachable" "loader timeout is ${timeout:-<unset>}"

# ── Greeter ────────────────────────────────────────────────────────────────
sddm=$(nix eval --raw "$SYS.services.displayManager.sddm.theme" 2>/dev/null)
report "$([ "$sddm" = "annixion" ] && echo 0 || echo 1)" \
  "the greeter uses the AnNIXion theme" "sddm theme is ${sddm:-<unset>}"

# plasma6.nix sets this too, so the priority has to actually win.
greeter=$(nix build --no-link --print-out-paths --impure --expr \
  'let p = import <nixpkgs> {}; in (import ./branding { pkgs = p; }).sddmTheme' \
  2>/dev/null)
if [ -z "$greeter" ]; then
  report 1 "the greeter theme builds" "sddmTheme did not build"
else
  conf="$greeter/share/sddm/themes/annixion/theme.conf"
  report "$([ -f "$conf" ] && echo 0 || echo 1)" \
    "the greeter theme ships a theme.conf" "missing $conf"

  # Breeze's greeter reads every asset path out of theme.conf. A path that
  # does not resolve renders as a blank panel, not an error.
  broken=""
  while IFS= read -r p; do
    [ -e "$p" ] || broken="$broken $p"
  done < <(sed -n 's/^\(background\|logo\)=//p' "$conf" 2>/dev/null)
  report "$([ -z "$broken" ] && echo 0 || echo 1)" \
    "every greeter asset resolves" "unresolved:$broken"

  accent=$(sed -n 's/^color=//p' "$conf" 2>/dev/null)
  report "$([ "$accent" = "#FF0033" ] && echo 0 || echo 1)" \
    "the greeter carries the signature red" "accent is ${accent:-<unset>}"

  name=$(sed -n 's/^Name=//p' "$greeter/share/sddm/themes/annixion/metadata.desktop" 2>/dev/null | head -1)
  report "$([ "$name" = "AnNIXion" ] && echo 0 || echo 1)" \
    "the greeter theme is not still called Breeze" "Name=${name:-<unset>}"
fi

# ── Installer image ────────────────────────────────────────────────────────
iso_theme=$(nix eval --raw "$ISO.boot.plymouth.theme" 2>/dev/null)
report "$([ "$iso_theme" = "annixion" ] && echo 0 || echo 1)" \
  "the live image boots the AnNIXion splash" "iso plymouth theme is ${iso_theme:-<unset>}"

# syslinux will not render an arbitrary size: the BIOS menu is drawn over a
# 640x480 image and silently ignores anything else.
bios=$(nix build --no-link --print-out-paths "$ISO.isoImage.splashImage" 2>/dev/null)
report "$([ -n "$bios" ] && [ "$(png_size "$bios")" = "640x480" ] && echo 0 || echo 1)" \
  "the BIOS splash is 640x480" "got $([ -n "$bios" ] && png_size "$bios" || echo '<no build>')"

efi=$(nix build --no-link --print-out-paths "$ISO.isoImage.efiSplashImage" 2>/dev/null)
report "$([ -n "$efi" ] && [ "$(png_size "$efi")" != "notpng" ] && echo 0 || echo 1)" \
  "the EFI splash is a readable PNG" "got $([ -n "$efi" ] && png_size "$efi" || echo '<no build>')"

echo
if [ "$fails" -gt 0 ]; then
  printf 'branding: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'branding: all checks passed\n'
