# A pure-Nix base64 encoder. Embedding an asset as a data: URI needs this at
# *evaluation* time — a build (pkgs.runCommand piping through `base64`) would
# return a derivation that `nix eval` never realises, so the path it hands
# back can point at a store object that does not exist yet.
#
# Lifted out of home/desktop/plasma/start-menu.nix, which still carries the
# only caveat: lib.strings.charToInt only covers tab/LF/CR and printable
# ASCII (32-126), so this throws on anything outside that range.
{ lib }:
str:
let
  alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  bytes = map lib.strings.charToInt (lib.stringToCharacters str);
  len = builtins.length bytes;
  byteAt = i: if i < len then builtins.elemAt bytes i else 0;
  sym = i: builtins.substring i 1 alphabet;
  quad =
    i:
    let
      b0 = byteAt (i * 3);
      b1 = byteAt (i * 3 + 1);
      b2 = byteAt (i * 3 + 2);
      rest = len - i * 3;
    in
    sym (b0 / 4)
    + sym ((lib.mod b0 4) * 16 + b1 / 16)
    + (if rest > 1 then sym ((lib.mod b1 16) * 4 + b2 / 64) else "=")
    + (if rest > 2 then sym (lib.mod b2 64) else "=");
in
lib.concatMapStrings quad (lib.range 0 ((len + 2) / 3 - 1))
