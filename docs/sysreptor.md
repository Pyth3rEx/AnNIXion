# SysReptor on AnNIXion

This page covers only what is specific to running SysReptor on AnNIXion — how it
is packaged, how to stand it up, and the wrapper that drives it. For using the
platform itself — designing reports, writing finding templates, scoring with
CVSS — see the upstream
[SysReptor documentation](https://docs.sysreptor.com/).

SysReptor is the reporting half of an engagement: notes and tool output go in,
a templated DOCX/PDF deliverable comes out. It is self-hosted and local — the
UI binds `127.0.0.1` only, and no finding leaves the machine.

---

## What ships, and why it is split

AnNIXion packages SysReptor in two halves:

- **`reptor` is a native Nix build.** The API client is a normal Python
  application on your `PATH`. It is the half you drive from a shell: push tool
  output into a finding, upload a note, fetch a report.
- **The platform itself runs in Docker.** It is a Django application with
  Postgres and Redis behind it, published only as a compose stack — there is no
  package to build. AnNIXion pins the upstream release bundle and drives it
  through a wrapper called `sysreptor`.

So `rebuild` gives you `reptor`, the `sysreptor` wrapper and a menu entry under
**Tools › Productivity** — but no running platform. You stand that up once,
on demand, with the wrapper.

The Community Edition is free to self-host and is what this installs. Features
reserved for the paid tiers (spell check, multi-user permissions) stay off; a
licence key goes in `app.env` if you have one.

---

## First run

The images come from the registry the first time, so the first start needs
network and a few minutes.

```bash
sysreptor setup        # write the deployment and its secrets, create the volumes
sysreptor up           # start it, create the login, import the designs
sysreptor open         # wait for it to answer, then open the UI
```

The first `up` creates the login declared in your config — `operator`, with the
same password the operator account ships with. **Change it at the first login**
(see [Accounts](#accounts)).

The UI is at **<http://127.0.0.1:8000>**. The menu entry runs `sysreptor open`,
which does the last two steps for you — including the wait, because the app
takes a while to answer after the containers start.

---

## The `sysreptor` wrapper

| Command | What it does |
|---|---|
| `sysreptor setup [--no-encryption]` | materialise the pinned deployment, generate secrets, create the volumes |
| `sysreptor up` | start app, database and cache |
| `sysreptor down` | stop them |
| `sysreptor restart` | restart them in place — keeps the containers, so it does **not** pick up a settings change |
| `sysreptor open` | bring it up, wait for the health check, open the UI |
| `sysreptor logs` | follow the stack's logs |
| `sysreptor status` | list running `sysreptor` containers |
| `sysreptor superuser [name]` | create another login, interactively |
| `sysreptor hash` | mint a password hash for the config |
| `sysreptor designs [--force]` | import the configured report designs |
| `sysreptor manage <args…>` | run `manage.py` inside the app container |
| `sysreptor backup [file.zip]` | full backup through `manage.py backup` |
| `sysreptor restore <file.zip>` | restore one — **replaces everything in the database** |
| `sysreptor env` / `url` / `config` | print the secrets path / the URL / the settings in force |

`sysreptor --help` prints the same table. `setup` runs automatically the first
time you `up` or `open`.

None of these take settings as flags. The port, the login, whether the instance
is reachable off this machine and which designs it carries are NixOS options —
see [Configuration](#configuration) below. `sysreptor config` prints what is in
force and where it came from.

The wrapper checks its preconditions and fails with a plain message rather than
a raw Docker error: it verifies the daemon is reachable before any command, and
creates the two external volumes the compose file requires but does not declare
as its own.

---

## Configuration

The deployment's settings are NixOS options under `annixion.sysreptor`, set in
`user/configuration.nix`. They are what the installer will collect on a first
install, which is why they live in the config rather than in flags on the
wrapper: an install should come back the same way twice.

```nix
# user/configuration.nix
annixion.sysreptor = {
  user = "operator";            # the login created on first start
  hashedPassword = "pbkdf2_sha256$600000$...";  # `sysreptor hash` mints one
  port = 8000;                  # above 1024, so rootless docker can bind it
  networkAccessible = false;    # loopback only
  encryptAtRest = true;         # AES-GCM, key in deploy/app.env
  designs = [ "htb" "offsec" "demo" ];   # all the published design packs
  findingTemplates = [ "annixion" ];     # the finding library to import
  plugins = [ "cyberchef" "customizetheme" ];  # default: all of them
  theme = "annixion";           # the palette the web UI wears
  demoProjects = false;         # the filled-in example reports
};
```

| Option | Default | What it decides |
|---|---|---|
| `user` | the desktop account's name | The login created on the first start. The platform's own account, not a Unix user |
| `hashedPassword` | the shipped default, hashed | That login's password, as a Django hash from `sysreptor hash`. `""` creates no account — see [Accounts](#accounts) |
| `port` | `8000` | Host port the UI answers on |
| `networkAccessible` | `false` | `false` binds `127.0.0.1`; `true` binds every interface **and opens the port in the firewall** |
| `allowedHosts` | `localhost`, `127.0.0.1`, plus the hostname when network-accessible | Host names Django answers to. Anything else gets a 400 |
| `encryptAtRest` | `true` | Whether `setup` generates an encryption key. Read once, when the secrets are first written |
| `designs` | `[ "htb" "offsec" "demo" ]` | Which official design packs to import |
| `findingTemplates` | `[ "annixion" ]` | Template libraries to import — `"annixion"`, `"demo"` |
| `plugins` | every community-edition plugin | Which plugins are enabled |
| `theme` | `"annixion"` | `"annixion"` or `"upstream"` colours for the web UI |
| `demoProjects` | `false` | Also import the example reports for each enabled pack |

The module writes `/etc/annixion/sysreptor.conf`, which the wrapper reads at
runtime. To apply a change:

```bash
sudo nixos-rebuild switch --flake ~/.dotfiles#AnNIXion   # or: rebuild
sysreptor up
```

`up` and not `restart`: the settings reach the app through `app.env` and the
published port, both of which a container reads when it is **created**.
`docker compose restart` reuses the container it already has, so it restarts
the old settings. `up` recreates whatever the change touched and leaves the
rest alone. The wrapper re-syncs `ALLOWED_HOSTS` into `app.env` on its next
run, without touching the keys beside it.

### Making it reachable from elsewhere

`networkAccessible = true` is a real change of posture, not a convenience
toggle. It publishes the UI on every interface over plain HTTP and opens the
port: anything that can route to this machine reaches a login page holding
every engagement's deliverables, with the session cookie in clear on the wire.

If a team genuinely needs the same instance, put a TLS-terminating reverse
proxy in front of it and name that proxy in `allowedHosts`:

```nix
annixion.sysreptor = {
  networkAccessible = true;
  allowedHosts = [ "reports.engagement.local" ];
};
```

For one operator, leave it off. Nothing about the local deployment is
degraded by loopback-only — `reptor` talks to it over the same address.

---

## Accounts

The login is declared, not set up by hand. `annixion.sysreptor.user` names it
and `hashedPassword` holds its password as a Django PBKDF2 hash; the first
start creates the account from the two.

```nix
annixion.sysreptor = {
  user = "operator";
  hashedPassword = "pbkdf2_sha256$600000$...";   # from `sysreptor hash`
};
```

The plaintext never enters the config, the Nix store or the generated
`/etc/annixion/sysreptor.conf` — which is `0400` and owned by the operator,
because a hash is still worth guessing offline. To change the password:

```bash
sysreptor hash    # prompts twice, prints a hash to paste into the config
```

...or just change it in the UI, which is simpler. **The account is created
once and never touched again**, so a password changed in the UI survives every
later start — the config cannot know about it, so it does not try to.

The shipped default is the same password the operator account ships with,
which means it is public knowledge. The Community Edition has no way to force
a change at first login — `must_change_password` exists in the data model but
only Professional enforces it — so changing it is on you. The roadmap retires
this default along with the system one, at the point the installer can ask.

`sysreptor superuser [name]` creates further accounts interactively, and user
management lives in the UI.

### There is no login-less mode

Every route that skips the login screen is Professional-edition only:

| Route | Status in the Community Edition |
|---|---|
| Remote-User header auth (`REMOTE_USER_AUTH_ENABLED`) | `professional_only` in upstream's settings; the endpoint refuses |
| SSO via OIDC | `professional_only` |
| Disabling local auth (`LOCAL_USER_AUTH_ENABLED`) | `professional_only` |

So the login stays. What AnNIXion does instead is make it cost nothing: the
account exists before you first open the UI, with a password you declared, so
there is no setup step between `rebuild` and writing a finding. Let the
browser remember it, and `reptor` never sees the login screen at all — it
authenticates with an API token.

Worth saying plainly: header-based auth would not be a good idea here even if
it were available. Upstream's own warning is that the header is trusted
unconditionally, so anything able to reach the app could log in as any user —
which, on a box holding client findings, trades a password for an open door.

---

## Report designs

A design is the template a report is rendered through: the HTML/CSS layout,
the cover page, the finding fields. AnNIXion ships the official **Hack The
Box** set and imports it the first time the platform starts — CPTS, CWES,
CDSA, CDEP, CWEE, CAPE, CJCA, CWPE and COAE. The
[CPTS example report](https://docs.sysreptor.com/assets/reports/HTB-CPTS-Report.pdf)
is what that design produces.

Every design pack upstream publishes is pinned here, and all three are
imported by default:

| Pack | What it is |
|---|---|
| `annixion` | **This distribution's own two** — see below |
| `htb` | The Hack The Box certification designs — CPTS, CWES, CDSA, CDEP, CWEE, CAPE, CJCA, CWPE, COAE |
| `offsec` | The OffSec set, OSCP included |
| `demo` | The three designs behind upstream's online demo — Margherita, Matrix, Calzone. Client-report layouts rather than certification ones, and the usual starting point for a house design |

Narrow the list if you would rather not have them all:

```nix
annixion.sysreptor.designs = [ "annixion" ];
```

### The AnNIXion designs

Three, one per discipline, built from `assets/sysreptor/designs` and rendered
with the mark substituted from `catalog/logo.nix` at build time:

**Engagement Report** covers a whole engagement rather than one discipline:
reconnaissance and OSINT, social engineering with a campaign-results table
(targets, interactions, credentials given, **reported**, time to first
report), the physical assessment with a per-site entry table and a narrative
the facilities team can act on, the attack narrative from initial access to
objective, and a detection timeline measuring what the defenders actually
saw. Findings carry a category and one of the three discipline tags.

**OSINT Report** is an intelligence product, not a pentest report. It opens
with a bottom line and key judgements carrying explicit confidence, records
the tasking and the legal basis for the collection, grades every source on
the Admiralty scale (reliability A–F, credibility 1–6), and separates what
was found from what it enables. Exposures replace findings, and severity is
assessed rather than computed — CVSS is optional throughout.

**Influence Operation Report** is the Puppet Master half: analysis of a
disinformation or influence campaign. It carries the narratives and the
account clusters with the coordination indicators that were actually applied,
reach separated from impact (visibility is not persuasion), a record of the
research personas used to collect and the OPSEC around them, and an
attribution section built on competing hypotheses rather than a single
story — with explicit caveats, because saying who runs an account is a claim
about a person. Elements are scored by assessed severity and authenticity,
each carrying its own confidence.

All three put the identity on the cover and keep the body pages white: a
deliverable gets printed, forwarded and read in a meeting, and a dark report
is a poor citizen in all three. The severity ramp is the conventional one —
red, orange, amber, blue, green — because a reader knows what an orange
*High* means, and the house palette does not get to repaint that.

All of them are fetched at build time and imported from the Nix store, so a
first run needs no network beyond the container images.

### Finding templates

A design is the layout; a template is the finding already written. AnNIXion ships its own library of **109 findings**, imported by default, in
`assets/sysreptor/templates` — one JSON file per finding, which is also how
you add to it.

It is organised along the three disciplines the browser profiles already
divide by, so the tag filter in **Templates** matches the way the rest of the
distribution is laid out:

| Tag | Count | Covers |
|---|---|---|
| `red` | 75 | Direct action: web and API, infrastructure, Active Directory, cloud, wireless, mobile, endpoint — and 25 **physical** findings: tailgating, badge cloning, door and biometric bypass, key and lock management, live network ports, server rooms, covert devices, alarm response, media disposal, out-of-hours contractors, building systems on the corporate network, sightlines, wireless reaching the car park |
| `puppet` | 26 | The persona side: phishing, QR and callback phishing, OAuth consent, pretext calls and help-desk reset bypass, MFA fatigue, payment fraud and authority impersonation, on-site and courier impersonation, dropped media, synthetic voice, new-starter targeting, insider recruitment, conference elicitation, reporting culture and the cost of challenging a colleague |
| `osint` | 21 | What an attacker finds before touching anything: breach and infostealer credentials, staff and executive exposure, document metadata, forgotten assets and subdomain takeover, certificate transparency, look-alike domains, recruitment material, supplier mapping, social media disclosing premises and routine, archived content |

Each carries a CVSS vector where one is meaningful — physical findings use
`AV:P`, social engineering `UI:R` — and `n/a` where a severity score would be
pretending.

```nix
annixion.sysreptor.findingTemplates = [ "annixion" "demo" ];  # add upstream's ten
annixion.sysreptor.findingTemplates = [ ];                    # none
```

Upstream's `demo` library is ten web findings that overlap ours; it is there
to compare wording against. Both are starting points — edit them into your own
voice before a client reads them.

**Adding one:** drop a JSON file into `assets/sysreptor/templates` following
the shape of its neighbours, `rebuild`, then `sysreptor designs`. Template ids
are fixed per file, so a re-import updates the template rather than cloning
it — which means you can edit a template here and push the change to an
existing instance.

---

## Plugins and the theme

Every official plugin that does anything in the Community Edition is enabled:
`cyberchef`, `checkthehash`, `graphqlvoyager`, `customizetheme`,
`markdownexport`, `projectnumber`, plus upstream's own defaults
`renderfindings` and `scanimport`.

Left out: `demoplugin`, which demonstrates the plugin system rather than doing
a job, and `webhooks`, `rendersections` and `jira`, which are
Professional-edition features.

```nix
annixion.sysreptor.plugins = [ "cyberchef" ];   # narrow the list
annixion.sysreptor.plugins = [ ];               # hand control back to the UI
```

Setting this writes `ENABLED_PLUGINS`, which takes precedence over the
application's own settings page — so the plugin checkboxes there go read-only.
An empty list leaves the UI in charge.

### The AnNIXion theme

`customizetheme` carries the distribution's palette into the web interface:
the signature red on the near-black ground the desktop uses, with the risk
scale on its conventional CVSS ramp, borrowing AnNIXion's values only where
they land on it —

| Severity | Colour | Class it borrows |
|---|---|---|
| Critical | `#FF0033` | offensive — the signature red |
| High | `#FF9300` | — the conventional orange |
| Medium | `#FFD000` | probe amber |
| Low | `#4A90FF` | forensic blue |
| Info | `#33E62B` | passive green |

Critical takes the signature red because it is already the colour of
"stop"; High stays orange, because a reader of a CVSS score knows what orange
means and a house colour there would read as a different severity.

The header logo goes with it. The mark is rendered from `catalog/logo.nix`,
the same drawing the launcher wears, and handed to the theme as a base64
`data:` URI through the `header-logo-url` variable. Because it is generated
from the catalog rather than pasted in, the two cannot drift apart.

```nix
annixion.sysreptor.theme = "upstream";   # SysReptor's own colours instead
```

### Example reports

Each design pack also has filled-in example reports showing what a finished
deliverable looks like. They are off by default, because they appear as
projects beside real engagements:

```nix
annixion.sysreptor.demoProjects = true;   # one set per enabled design pack
```

Each pack is imported **once**, recorded in
`~/.local/share/sysreptor/imported`, and then left alone — `importdemodata`
adds a fresh copy of every design each time it runs, so a start that re-imported
would leave nine HTB designs after nine starts. A design edited in the UI stays
edited.

```bash
sysreptor designs           # import anything configured but not yet imported
sysreptor designs --force   # import again, duplicates and all
```

To write your own, copy an imported design in the UI (**Designs › ⋮ ›
Duplicate**) and edit it there — the originals stay as the reference.

---

## Where things live

```
~/.local/share/sysreptor/deploy/     # the pinned compose files, refreshed by setup
├── app.env                          # your secrets — generated once, never overwritten
└── docker-compose.yml               # upstream's, materialised read-write
~/.local/share/sysreptor/imported    # which design packs this install has taken
/etc/annixion/sysreptor.conf         # the settings, generated from your NixOS config

docker volume sysreptor-db-data      # Postgres
docker volume sysreptor-app-data     # uploads, designs, rendered reports
```

The reports are in the Docker volumes, not in the deploy directory. `setup`
refreshes everything beside `app.env` and touches neither volume, so it is safe
to re-run.

---

## Secrets, and the one way to lose everything

`sysreptor setup` generates two things into `app.env`:

- a **Django secret key**, which signs sessions, and
- an **AES-GCM encryption key**, which encrypts the database at rest.

Encryption at rest is **on by default** here. That is the right default for a
machine holding client findings, and it has one consequence worth stating
plainly: **if `app.env` is lost, the reports are unreadable.** There is no
recovery path — the key is not stored anywhere else.

So back `app.env` up somewhere that is not this machine:

```bash
cp "$(sysreptor env)" /your/backup/location/
```

`setup` never overwrites an existing `app.env` — a second run keeps the keys the
data was written with, and says so. If you would rather not encrypt at all, run
`sysreptor setup --no-encryption` on a **fresh** install; switching afterwards
means exporting your data first.

`ALLOWED_HOSTS` is set to `localhost,127.0.0.1` to match the local bind. If you
ever expose this behind a reverse proxy, set it to the real hostname — see
upstream's [configuration reference](https://docs.sysreptor.com/setup/configuration/).

---

## `reptor`, the API client

`reptor` is on `PATH` after a `rebuild`, and it is how tool output gets into a
report without copy-paste:

```bash
reptor conf                                 # point it at http://127.0.0.1:8000, paste an API token
reptor nmap --xml --upload -i scan.xml      # an nmap run, formatted and uploaded
cat sslyze.json | reptor sslyze --json --push-findings
echo "callback at 14:02" | reptor note      # a note into the engagement's notebook
reptor file loot/*                          # evidence, as attachments
```

It also imports from Burp, Nessus, OpenVAS and Qualys, and
`reptor findingfromtemplate` turns your template library into findings on a
project. `reptor --help` lists the full set.

The API token comes from the UI, under your user's **API tokens**. Upstream
documents the full command set at
[docs.sysreptor.com/cli](https://docs.sysreptor.com/cli/getting-started/).

---

## Rootless Docker

AnNIXion's Docker daemon is rootless (see
[hardening.md](hardening.md#docker)). SysReptor needs nothing that rootless
withholds: it binds `127.0.0.1:8000`, which is above 1024, and uses no host
networking or raw sockets. Unlike the AdaptixC2 teamserver, it has no reason to
want a rootful daemon — unless you set `annixion.sysreptor.port` below 1024,
which rootless cannot bind. Leave the port high and put a proxy in front
instead.

If the daemon is not running, the wrapper says so — rootless starts on first
use, or `systemctl --user start docker`.

---

## Backups and updating

```bash
sysreptor backup engagement-2026-10.zip    # database, uploads and designs in one file
```

Restoring one replaces everything currently in the database, so the wrapper
asks before it does it:

```bash
sysreptor restore engagement-2026-10.zip
```

The version is pinned in `catalog/tools/productivity/sysreptor.nix` — the
`version` string, the deployment hash, and a hash per design pack. Upstream
publishes the design packs at an unversioned URL and refreshes them in place,
so those hashes are the only pin: bump one when a new certification design
lands. Then `rebuild` to get the new wrapper, and:

```bash
sysreptor backup pre-upgrade.zip   # first, always
sysreptor setup                    # refresh the compose files; secrets are kept
sysreptor up                       # pull the new images and migrate
```

Upstream's own upgrade notes are worth reading before a major jump, especially
where they move Postgres between major versions.
