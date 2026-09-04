# Usage

Day-to-day operation: the commands AnNIXion ships, the four browser profiles,
and how Burp interception and VPN enforcement are set up and overridden.

---

## Commands

Everything AnNIXion ships is prefixed `annixion-`, so `annixion-<Tab>` lists the
lot. Every one of them takes `-h` / `--help`.

| Command | Purpose |
|---|---|
| `annixion-install` | Install to disk from the live ISO |
| `annixion-cc` | Control center — Wi-Fi, Bluetooth, network killswitch |
| `annixion-burp-ca` | Fetch Burp's CA so Firefox trusts intercepted HTTPS |
| `annixion-vpn-run` | Run any command inside the VPN-enforced slice |
| `annixion-vpn-browser` | Launch a Firefox profile inside that slice |
| `annixion-vpn-status` | Tunnel, killswitch and slice state |
| `annixion-vpn-tunnels` | List every interface that qualifies as a live tunnel |
| `annixion-vpn-detect` | Print the first live tunnel, or exit 1 |
| `annixion-vpn-killswitch-load` | Arm the nftables killswitch (needs root) |
| `annixion-raise` | Focus a running window by `WM_CLASS`, or launch the app |

The Hack The Box example in `user/examples/` adds `annixion-htb-hosts` and
`annixion-htb-vpn` once imported.

Internal helper scripts carry the prefix too, so an AnNIXion store path is
recognisable in `ps` output, but they take no arguments and are not meant to be
run by hand.

Shell aliases (`rebuild`, `upgrade`, `gs`, `ll`, …) are not prefixed — they are
typing shortcuts, and several deliberately shadow standard tools.

---

## Firefox profiles

Four isolated profiles launch from the desktop. Each has its own cookies, cache,
and extensions. OSINT is the default: it owns `http`, `https` and `text/html`, so
a link clicked in any other application opens there.

| Profile | Egress | Purpose |
|---|---|---|
| **Unsafe Browser** | Direct (no proxy) | Captive portals, clearnet sessions. Keeps nothing: permanent private browsing, a blank page every launch, no history, cache or session carried across restarts. |
| **Red Team** | Burp Suite — `127.0.0.1:8080` | Web app testing, interception. Blocks if Burp is not running. No VPN required — internal targets are reachable. |
| **OSINT** | VPN tunnel — kernel-enforced | Source gathering, investigations. The default profile, and where links from other applications open. Refuses to launch without a VPN tunnel. |
| **Puppet Master** | VPN tunnel — kernel-enforced | Persona management, containers. Refuses to launch without a VPN tunnel. |

---

## Red Team — Burp Suite setup

The Red Team profile routes all traffic through Burp. If Burp is not running, the browser refuses to connect — this is intentional.

**Before browsing:**

1. Start Burp Suite
2. Confirm the proxy listener is active at `127.0.0.1:8080`:
   `Proxy > Proxy settings > Proxy listeners`
3. Launch **Firefox - Red Team** from the desktop

The Burp proxy is set at the profile level (`network.proxy.*`), not through an
extension, so interception does not depend on an addon staying installed and
enabled. `failover_direct = false` means a request never silently falls back to
a direct connection when Burp is down. No manual configuration needed.

FoxyProxy is still installed on this profile, for ad-hoc switching mid-engagement
— an upstream proxy, a SOCKS pivot, a second Burp. It ships **disabled**, with
the Burpsuite entry present as a worked example to copy rather than an active
route, so out of the box it changes nothing.

Enabling it is a real trade, not just a toggle: an extension holding the proxy
API overrides `network.proxy.*` wholesale, `failover_direct` included. While
FoxyProxy is driving, the profile's "fail rather than connect directly"
guarantee is whatever FoxyProxy is pointed at instead. Switch it back to
**Disable** when you are done and the profile prefs resume.

### Running Red Team through a VPN

The profile does **not** require a tunnel, because red team targets are as often
on the LAN in front of you as on the internet, and an attribution control has no
business gating reachability. Burp is the control that matters here, and it
still fails closed.

When you do want the tunnel — external infrastructure, a lab, anything where the
source address matters — launch it explicitly:

```console
$ annixion-vpn-browser "Red Team"
$ annixion-vpn-run burpsuite
```

Launch **both** through the slice or neither. Firefox only ever talks to
loopback, so *Burp* makes the real requests: a Burp started bare while the
browser is enforced leaves egress unconfined and the enforcement decorative.

### SSL interception — Burp CA certificate

Burp signs intercepted HTTPS traffic with its own CA (PortSwigger CA). Firefox needs to trust that cert. Run this once per machine after starting Burp:

```bash
annixion-burp-ca    # fetches Burp's CA from the running proxy, saves to ~/.dotfiles/assets/certs/
```

Then restart Firefox. No `rebuild` is needed: the enterprise policy records the
*path* to the cert, not its contents, so Firefox re-reads the file every time it
starts.

Burp must be running on `127.0.0.1:8080` when you run `annixion-burp-ca`. After that, the cert is stable — it only needs to be re-run if Burp's data directory is wiped and it regenerates its CA.

> The cert file is machine-specific and excluded from git via `.gitignore`.

After import, Burp uses the same CA as Firefox. HTTPS interception works without certificate warnings.

---

## VPN enforcement — OSINT & Puppet Master

Both profiles are confined to the VPN tunnel **in the kernel**, not by proxy
preferences. Bring up your VPN however you like — NetworkManager, `wg-quick`, a
raw `.ovpn`; enforcement is VPN-agnostic and matches the tunnel interface.

Red Team launches unenforced by default, since its job is reaching the target
rather than hiding the source — see [above](#running-red-team-through-a-vpn) for
running it through the tunnel when that is what you want.

How it works (`system/vpn-enforcement.nix`):

1. Enforced applications run inside a dedicated systemd user slice —
   the browser profiles launched through `annixion-vpn-browser`, and anything
   started with `annixion-vpn-run`.
2. Tunnels are identified by **device type** (WireGuard, tun/tap, PPP, xfrm, …),
   not by interface name, so vendor naming doesn't matter — Mullvad's
   `ee-tll-wg-001` is recognised as readily as `wg0`.
3. An nftables rule matches that cgroup and permits egress **only** through the
   tunnels that are live when the killswitch is armed. Everything else is
   rejected.
4. `annixion-vpn-browser` (profiles) and `annixion-vpn-run` (any command)
   refuse to launch at all unless a tunnel is up and carrying a route.

A tunnel counts as carrying a route if it has one in **any** routing table, not
just `main` — `wg-quick` and Mullvad install their default route in a private
table selected by an fwmark rule, and a `main`-only check reports a perfectly
healthy tunnel as dead.

WireGuard's own encapsulated packets are permitted explicitly. They keep the
socket of the inner packet they carry, so the cgroup match catches them, and
their fwmark deliberately routes them around the tunnel table and out the
physical interface. Blocking them would stop the tunnel transmitting for
enforced processes entirely. They are the tunnel, and already encrypted, so
allowing them is what the boundary means — and since setting `SO_MARK` requires
`CAP_NET_ADMIN`, an enforced browser cannot forge the mark to escape.

Anything that makes network requests on a profile's behalf has to be in the
slice too, or it becomes the leak — Burp above all, since an intercepting proxy
makes every request the browser appears to make. The menu entry launches it
unenforced, so pair `annixion-vpn-run burpsuite` with any profile you launch
through `annixion-vpn-browser`.

This is fail-closed by construction: if the tunnel drops mid-session, traffic
from those profiles stops leaving immediately — there is no default route to
fall back to. It also covers what proxy prefs never could: WebRTC, OCSP,
captive-portal probes, and anything that races the profile load.

Check the current state:

```console
$ annixion-vpn-status
tunnel:     live — wg0
killswitch: armed
slice:      annixion-vpn.slice active
```

The ruleset is a snapshot of the tunnels that were live when it was armed. If
your tunnel drops and returns under a *different* interface name mid-session,
the stale rule matches nothing and traffic stops — fail-closed, as intended.
Relaunching the profile re-arms it.

Tunnels that don't present as a recognised device type can be matched by name
via `annixion.vpnEnforcement.tunnelInterfaces`. An unrecognised tunnel fails
**closed** (traffic blocked), never open.

To change the message shown when you launch without a VPN, set
`annixion.vpnEnforcement.errorMessageCommand` to any command — its stdout
becomes the dialog text, and `ANNIXION_VPN_PROFILE` is exported to it.

### DNS

Plaintext DNS is rejected for these profiles even on loopback, since a local
resolver would forward the query from outside the cgroup and escape
enforcement. They use DNS-over-HTTPS through the tunnel instead, in TRR-only
mode (`network.trr.mode = 3`) so there is no plaintext fallback.

That creates a bootstrap problem — Firefox needs DNS to reach its own DoH host,
and mode 3 forbids the only mechanism it has. `network.trr.bootstrapAddr` pins
the resolver's IP so no lookup is needed; without it the profile has no DNS at
all. The pref was `bootstrapAddress` before Firefox 89, and the old name is
silently ignored.

Resolver choice differs by profile, deliberately:

| Profile | Resolver | Why |
| --- | --- | --- |
| Red Team | `dns10.quad9.net` (9.9.9.10) | Unfiltered — a blocklist would hide the infrastructure under test |
| OSINT | `dns10.quad9.net` (9.9.9.10) | Unfiltered — investigations routinely target flagged domains |
| Puppet Master | `dns.quad9.net` (9.9.9.9) | Blocklisted — persona browsing has no reason to reach malicious hosts |

Firefox has no secondary-DoH-provider setting; its only fallback is plaintext
Do53, which the killswitch blocks and which would leak. There is therefore no
automatic failover — switching provider is a config change, shown under the
override examples below.

#### Everything that is not Firefox

Burp, `sqlmap`, `ffuf` and anything else launched through `annixion-vpn-run`
resolve names through glibc, which does not do the lookup itself — it hands the
query to `nscd`. That daemon runs *outside* the enforced cgroup, so blocking
DNS in the ruleset stops only direct queries and nothing that ordinary software
does. Left alone, an enforced tool's lookups would keep resolving in the clear
after the tunnel dropped, leaking precisely the names it was visiting.

The launcher therefore masks the `nscd` socket and supplies a private
`/etc/resolv.conf` naming resolvers reachable only through the tunnel, so the
process resolves for itself and DNS fails closed with everything else. Change
them with `annixion.vpnEnforcement.dnsServers`; setting it to `[ ]` restores
the system resolver and gives up this guarantee.

---

## Bypassing proxy enforcement via user overrides

All proxy settings can be overridden per-machine without touching the shared config. Create a file in `user/` and import it from `user/home.nix`:

```nix
# user/home.nix
imports = [ ./firefox-proxy.nix ];
```

`lib.mkForce` is required — the base config does not use `lib.mkDefault` on these prefs.

**Disable Burp enforcement** (Red Team browsing works without Burp running):

```nix
{ lib, ... }:
{
  programs.firefox.profiles."redteam".settings = {
    "network.proxy.type"            = lib.mkForce 0;
    "network.proxy.failover_direct" = lib.mkForce true;
  };
}
```

**Redirect Red Team to a remote Burp** (e.g. `192.168.1.50:8080`):

```nix
{ lib, ... }:
{
  programs.firefox.profiles."redteam".settings = {
    "network.proxy.http"      = lib.mkForce "192.168.1.50";
    "network.proxy.http_port" = lib.mkForce 8080;
    "network.proxy.ssl"       = lib.mkForce "192.168.1.50";
    "network.proxy.ssl_port"  = lib.mkForce 8080;
  };
}
```

**Recognise an extra tunnel interface name**. Only needed for a tunnel that
presents as an unrecognised device type — WireGuard, tun/tap, PPP and xfrm
devices are detected by type whatever they are called:

```nix
{
  annixion.vpnEnforcement.tunnelInterfaces = [
    "tun*"
    "wg*"
    "corp-vpn0"
  ];
}
```

**Switch a profile's DoH resolver to Cloudflare**. Change both prefs together —
`bootstrapAddr` must be an IP of the host in `uri`, or the profile loses DNS
entirely:

```nix
{ lib, ... }:
{
  programs.firefox.profiles."osint".settings = {
    "network.trr.uri" =
      lib.mkForce "https://cloudflare-dns.com/dns-query";
    "network.trr.bootstrapAddr" = lib.mkForce "1.1.1.1";
  };
}
```

**Customise the "no VPN" message** (any command; stdout becomes the dialog):

```nix
{ pkgs, ... }:
{
  annixion.vpnEnforcement.errorTitle = "Tunnel Down";
  annixion.vpnEnforcement.errorMessageCommand = toString (
    pkgs.writeShellScript "vpn-msg" ''
      echo "No tunnel — '$ANNIXION_VPN_PROFILE' will not open."
      echo "Active engagement: $(cat /etc/annixion/engagement 2>/dev/null || echo none)"
    ''
  );
}
```

**Disable VPN enforcement entirely** (removes the killswitch and the launch
guard — the OSINT and Puppet profiles will then browse over whatever route the
system has):

```nix
{
  annixion.vpnEnforcement.enable = false;
}
```

Note that the profile settings alone no longer enforce anything: enforcement
lives in the kernel, so overriding `network.proxy.*` for OSINT or Puppet will
not re-open egress. Use the option above.

Run `rebuild` after any change to `user/`.
