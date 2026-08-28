#!/usr/bin/env bash
# A zone transfer is the first thing recon asks for, so a broken one has to fail
# loudly instead of reading as "that zone is locked down". zonetransfer.me is
# published to allow AXFR, so "Transfer failed." here is this machine's fault
# rather than the zone's — usually a resolver on the path hijacking port 53.
set -uo pipefail

ZONE="${AXFR_ZONE:-zonetransfer.me}"
if [ "$#" -gt 0 ]; then
  SERVERS=("$@")
else
  SERVERS=(nsztm1.digi.ninja nsztm2.digi.ninja)
fi

fails=0
ok() { printf 'ok   %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  fails=$((fails + 1))
}

DIG_OPTS=(+time=5 +tries=1)
# The interception probe always tests port 53; only the transfer follows this.
XFR_OPTS=("${DIG_OPTS[@]}")
[ -n "${AXFR_PORT:-}" ] && XFR_OPTS+=(-p "$AXFR_PORT")

if ! command -v dig >/dev/null 2>&1; then
  fail "dig is not on PATH"
  echo
  echo "dns-axfr: cannot test a zone transfer without dig"
  exit 1
fi

# ── Is port 53 reaching the server we named? ───────────────────────────────
# RFC 5737 TEST-NET-1 is routable to nothing, so nothing can answer from it.
# A reply means something on the path answers for every destination alike,
# which also means AXFR never reaches an authoritative server.
# dig prints its ";; communications error" lines to stdout even under +short,
# so a silent address is not an empty capture — drop them and keep real answers.
intercepted=0
probe=$(dig "${DIG_OPTS[@]}" +short A example.com @192.0.2.1 2>/dev/null | grep -v '^;')
if [ -n "$probe" ]; then
  intercepted=1
  fail "port 53 is intercepted: 192.0.2.1 answered for example.com ($(echo "$probe" | tr '\n' ' '))"
else
  ok "port 53 is not intercepted (192.0.2.1 stayed silent)"
fi

# ── The transfer itself ────────────────────────────────────────────────────
for ns in "${SERVERS[@]}"; do
  out=$(dig "${XFR_OPTS[@]}" +tcp axfr "@${ns}" "$ZONE" 2>&1)

  if printf '%s' "$out" | grep -q 'Transfer failed\.'; then
    fail "AXFR $ZONE @$ns: Transfer failed."
    continue
  fi

  if printf '%s' "$out" | grep -qiE 'connection refused|timed out|no servers could be reached'; then
    reason=$(printf '%s' "$out" | grep -iEm1 'connection refused|timed out|no servers could be reached')
    fail "AXFR $ZONE @$ns: ${reason#";; "}"
    continue
  fi

  # A real transfer ends with dig's record tally and carries the zone apex.
  records=$(printf '%s' "$out" | grep -cE "^${ZONE}\.[[:space:]]")
  if ! printf '%s' "$out" | grep -q 'XFR size:' || [ "$records" -eq 0 ]; then
    fail "AXFR $ZONE @$ns: answered, but returned no zone data"
    continue
  fi

  ok "AXFR $ZONE @$ns: $(printf '%s' "$out" | sed -n 's/.*XFR size: \([0-9]*\) records.*/\1/p') records"
done

echo
if [ "$fails" -eq 0 ]; then
  echo "dns-axfr: zone transfers work from here"
elif [ "$intercepted" -eq 1 ]; then
  echo "dns-axfr: $fails check(s) failed — a resolver on the path is answering"
  echo "for every address on port 53, so AXFR never reaches the nameserver."
  echo "A VPN with DNS hijacking enabled is the usual cause."
else
  echo "dns-axfr: $fails check(s) failed"
fi
exit "$fails"
