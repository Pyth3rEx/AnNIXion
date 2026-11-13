#!/usr/bin/env bash
# Four bounds that only show up as a slow leak: an uncapped journal, an
# unoptimised store, no memory cushion, and a wpa_supplicant with no radio to
# manage (#168). None of them fail loudly, so each is checked against the
# configuration the next activation would apply rather than a running system.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYS='.#nixosConfigurations.AnNIXion-ci'
CFG="$SYS.config"
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

cd "$ROOT" || exit 1

# ── The journal ────────────────────────────────────────────────────────────
journal=$(nix eval --raw "$CFG.services.journald.extraConfig" 2>/dev/null)
report "$(grep -q 'SystemMaxUse=' <<< "$journal" && echo 0 || echo 1)" \
  "the journal has a size cap" \
  "journald.extraConfig is ${journal:-<empty>}"

# Persistence is the thing a cap must not have been bought with.
storage=$(nix eval --raw "$CFG.services.journald.storage" 2>/dev/null)
report "$([ "$storage" = "persistent" ] && echo 0 || echo 1)" \
  "the journal still survives a reboot" "Storage is ${storage:-<unset>}"

# ── The store ──────────────────────────────────────────────────────────────
optimise=$(nix eval "$CFG.nix.optimise.automatic" 2>/dev/null)
report "$([ "$optimise" = "true" ] && echo 0 || echo 1)" \
  "the store is deduplicated on a timer" \
  "nix.optimise.automatic is ${optimise:-<unset>}"

# GC is what optimise sits next to, and losing it would be the quiet
# regression that makes dedup look sufficient on its own.
gc=$(nix eval "$CFG.nix.gc.automatic" 2>/dev/null)
report "$([ "$gc" = "true" ] && echo 0 || echo 1)" \
  "garbage collection is untouched" "nix.gc.automatic is ${gc:-<unset>}"

# ── Memory cushion ─────────────────────────────────────────────────────────
zram=$(nix eval "$CFG.zramSwap.enable" 2>/dev/null)
report "$([ "$zram" = "true" ] && echo 0 || echo 1)" \
  "there is swap to degrade into" "zramSwap.enable is ${zram:-<unset>}"

# ── wpa_supplicant ─────────────────────────────────────────────────────────
# The unit, not the option: NetworkManager enables networking.wireless at
# normal priority, so the question is whether the override actually won.
unit=$(nix eval --apply 'u: u ? wpa_supplicant' "$CFG.systemd.services" 2>/dev/null)
report "$([ "$unit" = "false" ] && echo 0 || echo 1)" \
  "no wpa_supplicant unit is built" "systemd.services.wpa_supplicant exists"

# ── The gate ───────────────────────────────────────────────────────────────
# Hardcoding it off would pass every check above and leave a laptop with no
# way to get wifi back.
on=$(nix eval --apply \
  "sys: (sys.extendModules {
     modules = [ { annixion.hardware.wireless = true; } ];
   }).config.systemd.services ? wpa_supplicant" \
  "$SYS" 2>/dev/null)
report "$([ "$on" = "true" ] && echo 0 || echo 1)" \
  "setting the option brings wpa_supplicant back" \
  "with annixion.hardware.wireless = true, the unit is ${on:-<unset>}"

# Ethernet and the VPN plugin must not have been collateral.
nm=$(nix eval "$CFG.networking.networkmanager.enable" 2>/dev/null)
report "$([ "$nm" = "true" ] && echo 0 || echo 1)" \
  "NetworkManager is unaffected" "networkmanager.enable is ${nm:-<unset>}"

echo
if [ "$fails" -gt 0 ]; then
  printf 'resource-housekeeping: %d check(s) failed\n' "$fails"
  exit 1
fi
printf 'resource-housekeeping: all checks passed\n'
