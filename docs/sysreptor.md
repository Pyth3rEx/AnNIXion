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
sysreptor up           # pull and start app, database and cache
sysreptor superuser    # create your login (prompts for a password)
sysreptor open         # wait for it to answer, then open the UI
```

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
| `sysreptor restart` | restart them (e.g. after editing `app.env`) |
| `sysreptor open` | bring it up, wait for the health check, open the UI |
| `sysreptor logs` | follow the stack's logs |
| `sysreptor status` | list running `sysreptor` containers |
| `sysreptor superuser [name]` | create a login (default `operator`) |
| `sysreptor manage <args…>` | run `manage.py` inside the app container |
| `sysreptor backup [file.zip]` | full backup through `manage.py backup` |
| `sysreptor restore <file.zip>` | restore one — **replaces everything in the database** |
| `sysreptor env` / `url` | print the secrets path / the local URL |

`sysreptor --help` prints the same table. `setup` runs automatically the first
time you `up` or `open`.

The wrapper checks its preconditions and fails with a plain message rather than
a raw Docker error: it verifies the daemon is reachable before any command, and
creates the two external volumes the compose file requires but does not declare
as its own.

---

## Where things live

```
~/.local/share/sysreptor/deploy/     # the pinned compose files, refreshed by setup
├── app.env                          # your secrets — generated once, never overwritten
└── docker-compose.yml               # upstream's, materialised read-write

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
want a rootful daemon.

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

The version is pinned in `catalog/tools/productivity/sysreptor.nix` (the
`version` string and the source hash). Bump both, `rebuild` to get the new
wrapper, then:

```bash
sysreptor backup pre-upgrade.zip   # first, always
sysreptor setup                    # refresh the compose files; secrets are kept
sysreptor up                       # pull the new images and migrate
```

Upstream's own upgrade notes are worth reading before a major jump, especially
where they move Postgres between major versions.
