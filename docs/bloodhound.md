# BloodHound CE on AnNIXion

## What ships, and why it is split

Upstream ships no package that starts on its own: the server needs Postgres
and Neo4j reachable and a config telling it where, and has no opinion on how
those two get there. Packaging it as a bare binary — which is what this
distribution first shipped — builds and installs cleanly and then fails the
moment you run it, with nothing behind it to connect to. That gap is what
this page is about closing.

The fix mirrors [SysReptor's](sysreptor.md): a pinned
`docker-compose.yml` (upstream's own, at
`examples/docker-compose/docker-compose.yml`), materialised into a state
directory and driven by the `bloodhound` wrapper. Three containers —
`app-db` (Postgres), `graph-db` (Neo4j) and `bloodhound` (the server, with
the UI built in) — found each other inside that compose file already;
nothing here reimplements that.

Deployment settings are `system/bloodhound.nix`, read at runtime from
`/etc/annixion/bloodhound.conf`. See docs/hardening.md ("Docker") for the
rootless daemon this leans on.

---

## First run

There is no manual setup step. The menu entry runs `bloodhound open`, and
every command below bootstraps the deployment itself the first time it is
missing — `up`, `open`, `down`, `restart` and `logs` all do this before
anything else, so clicking BloodHound CE in a freshly installed AnNIXion
already works:

```bash
bloodhound open    # pulls the images (slow, online, once), starts the
                    # stack, waits for it, opens the UI — nothing before it
bloodhound logs    # read the admin password here — see "Accounts" below
```

`setup` still exists as its own command — materialise the compose file and
the database passwords without starting anything — but it is there for
inspecting or pre-staging the deployment ahead of time, not because any
other command needs it run first.

## The `bloodhound` wrapper

| Command | Does |
|---|---|
| `setup` | Materialise the compose file; write `POSTGRES_PASSWORD`/`NEO4J_SECRET` if they don't exist yet |
| `up` / `down` / `restart` | The app, its database and its graph store |
| `open` | Bring it up, wait for it to answer, open the UI |
| `logs` | Follow the containers' logs — where the first admin password appears |
| `status` | List running `bloodhound` containers |
| `config` | Print the settings in force |
| `url` | Print the UI's URL |

---

## Configuration

```nix
# user/configuration.nix
annixion.bloodhound = {
  principalName = "operator";
  email = "operator@localhost";
  port = 8080;
};
```

| Option | Default | Means |
|---|---|---|
| `principalName` | the operator account's name | Admin login name |
| `email`, `firstName`, `lastName` | `operator@localhost`, "AnNIXion", "Operator" | Admin account metadata — not secret, safe to declare |
| `port` | `8080` | Host port the UI answers on |
| `networkAccessible` | `false` | Publish on every interface and open the firewall, instead of loopback only |
| `forcePasswordChange` | `true` | Make the admin account reset its password on first login (`default_admin.expire_now`) |
| `recreateDefaultAdmin` | `false` | Recreate the admin account on every start if it's missing — lockout recovery |

Changing a setting and rebuilding updates `/etc/annixion/bloodhound.conf`;
`bloodhound up` (or `setup`) syncs it into the deployment without touching
the database passwords already generated.

### Making it reachable from elsewhere

Off, the graph is reachable only from this machine — what a single operator
needs. On, anything that can route here reaches the login page over plain
HTTP: every host, user, group and ACL edge collected off the target domain,
behind one password. Turn it on for a team sharing one instance and put a
TLS-terminating proxy in front of it.

---

## Accounts

The admin account's *identity* is declared — `principalName`, `email`,
`firstName`, `lastName` above — but its **password is not**. Left for
BloodHound itself to mint, a strong random password is generated on the very
first start and printed once to the app container's log:

```bash
bloodhound logs   # look for "Initial Password Set To: ..."
```

That is deliberate, not a gap this distribution means to fill in later.
SysReptor's login can be declared with a pre-hashed password because Django
accepts a hash at account-creation time; BloodHound's `default_admin.password`
config key takes the plaintext instead, hashed only after the server reads
it. A plaintext secret in `user/configuration.nix` ends up in the Nix store,
which is not a safe place for one — so the password stays out of Nix
entirely and the account is read once, the way upstream already designed it
to be read.

`forcePasswordChange` (default on) makes that first login demand a new
password immediately, which is the secure default. Turn it off for a
headless box an automated tool queries without a human ever opening the UI
to clear that prompt.

### There is no login-less mode

Unlike SysReptor, this is not an edition gate — BloodHound Community Edition
and Enterprise share one codebase, and CE already carries full user
management, SAML and OIDC. None of that is the question, though: SAML and
OIDC are *other ways to log in*, not *no login*. Every key in BloodHound's
config — `bind_addr`, `tls`, `saml.*`, `crypto.*`, every `enable_*` and
`disable_*` flag documented at
[bloodhound.specterops.io/manage-bloodhound/bh-config](https://bloodhound.specterops.io/manage-bloodhound/bh-config)
— was read end to end for one that skips the login screen. There isn't one.

So the login stays, on this network and off it. `forcePasswordChange = false`
above removes the one bit of friction that is actually optional — the forced
reset of the first password, not the screen that asks for it.

---

## Collecting data

This module deploys the graph; two menu entries beside it, both in the same
Lateral Movement node, do the collecting:

| Collector | Runs | Against |
|---|---|---|
| **BloodHound.py** (`bloodhound-python`) | this box, with an already-valid domain account | on-prem AD, over LDAP/SMB/Kerberos |
| **AzureHound** (`azurehound`) | this box, with an already-valid credential or a device-code login | Entra ID, over the Graph API |

Each writes a `.zip` you drag into the UI's upload page — no wiring between
them and the `bloodhound` wrapper beyond that.

**SharpHound** stays out on purpose: it is a Windows-only .NET binary with
nothing to run on this Linux box, and it already ships inside BloodHound
CE's own container image — download it from the UI's own "Download
Collectors" page and run it from a domain session instead.

---

## Where things live

| Path | What |
|---|---|
| `~/.local/share/bloodhound/deploy/docker-compose.yml` | The pinned compose file, refreshed on every `setup` |
| `~/.local/share/bloodhound/deploy/.env` | Database passwords (generated once, `chmod 600`) and the synced settings above |
| `/etc/annixion/bloodhound.conf` | What `annixion.bloodhound` wrote — world-readable; it carries no secret |

Losing `.env` loses the database passwords, which loses the running
containers' ability to reach their own data — back it up with the rest of
`~/.local/share` or treat a lost one as "start over": the graph itself lives
in the `postgres-data`/`neo4j-data` Docker volumes, which `.env` does not
touch and `bloodhound setup` never deletes.

## Rootless Docker

Covered once, for every container-backed tool on this distribution, in
[hardening.md](hardening.md#docker).
