# TLS/crypto toolkit — cert generation, inspection, conversion
# Installed system-wide but never shown: no menu entry, no mark.
#
# Pinned to openssl_4_0 rather than the nixpkgs default (still openssl_3_6):
# CVE-2026-63073/-75803/-14457/-54874/-63072/-63075/-63076/-63074 only have
# fixes in the 4.0 branch. See issue #151 for the closure-wide rebuild this
# forces and the packages it was checked against.
_: {
  package = p: p.openssl_4_0;
}
