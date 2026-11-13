# Bounds on the two things that grow without anyone asking: the journal and
# memory pressure. Both are defaults, so user/configuration.nix overrides
# either in one line (#168).
{
  lib,
  ...
}:

{
  # journald falls back to 10% of the filesystem when no cap is set — a ~19 GB
  # ceiling on a 195 GB root, reached slowly and never noticed. 512M keeps
  # enough history to debug a boot or a killswitch trip, which is what this
  # journal is actually read for; Storage=persistent stays, because losing
  # logs across a reboot would lose exactly those.
  services.journald.extraConfig = lib.mkDefault "SystemMaxUse=512M";

  # No swap at all means a heavy scan or a parallel build meets the OOM killer
  # rather than degrading. zram buys a cushion without touching the disk
  # layout, which a swap partition or file would need installer work to do.
  zramSwap.enable = lib.mkDefault true;
}
