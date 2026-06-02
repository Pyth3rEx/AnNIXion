# Usage

## Firefox profiles

Four isolated profiles launch from the desktop. Each has its own cookies, cache, and extensions.

| Profile | Proxy | Purpose |
|---|---|---|
| **Unsafe Browser** | Direct (no proxy) | Captive portals, clearnet sessions. Default when running bare `firefox`. |
| **Red Team** | Burp Suite — `127.0.0.1:8080` | Web app testing, interception. Blocks all traffic if Burp is not running. |
| **OSINT** | VPN SOCKS5 — `127.0.0.1:1080` | Source gathering, investigations. Blocks all traffic if VPN is not running. |
| **Puppet Master** | VPN SOCKS5 — `127.0.0.1:1080` | Persona management, containers. Blocks all traffic if VPN is not running. |

---

## Red Team — Burp Suite setup

The Red Team profile routes all traffic through Burp. If Burp is not running, the browser refuses to connect — this is intentional.

**Before browsing:**

1. Start Burp Suite
2. Confirm the proxy listener is active at `127.0.0.1:8080`:
   `Proxy > Proxy settings > Proxy listeners`
3. Launch **Firefox - Red Team** from the desktop

FoxyProxy is pre-loaded with the Burp proxy and set to intercept all traffic. No manual configuration needed.

### SSL interception — Burp CA certificate

Burp signs intercepted HTTPS traffic with its own CA (PortSwigger CA). Firefox needs to trust that cert. Run this once per machine after starting Burp:

```bash
burp-ca    # fetches Burp's CA from the running proxy, saves to ~/.dotfiles/assets/certs/
rebuild    # Firefox picks it up via enterprise policy
```

Burp must be running on `127.0.0.1:8080` when you run `burp-ca`. After that, the cert is stable — it only needs to be re-run if Burp's data directory is wiped and it regenerates its CA.

> The cert file is machine-specific and excluded from git via `.gitignore`.

After import, Burp uses the same CA as Firefox. HTTPS interception works without certificate warnings.

> These files are machine-specific and excluded from git. Do not commit them.

---

## OSINT & Puppet Master — VPN setup

Both profiles enforce all traffic through a SOCKS5 proxy at `127.0.0.1:1080`. Nothing connects if no VPN is running on that port.

Common VPN clients and their default SOCKS5 addresses:

| VPN / Tool | Default SOCKS5 |
|---|---|
| Mullvad (SOCKS5 proxy) | `127.0.0.1:1080` |
| Tor (system daemon) | `127.0.0.1:9050` |
| ProxyChains / custom | Port declared in your config |

If your VPN uses a different port, update `network.proxy.socks_port` in `home/firefox/osint.nix` and `home/firefox/puppet.nix` and run `rebuild`.

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

**Swap VPN port for OSINT and Puppet** (e.g. Tor at 9050):

```nix
{ lib, ... }:
{
  programs.firefox.profiles."osint".settings = {
    "network.proxy.socks_port" = lib.mkForce 9050;
  };
  programs.firefox.profiles."puppet".settings = {
    "network.proxy.socks_port" = lib.mkForce 9050;
  };
}
```

**Disable VPN enforcement entirely** for a profile:

```nix
{ lib, ... }:
{
  programs.firefox.profiles."osint".settings = {
    "network.proxy.type"            = lib.mkForce 0;
    "network.proxy.failover_direct" = lib.mkForce true;
  };
}
```

Run `rebuild` after any change to `user/`.
