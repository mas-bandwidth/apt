# Getting into the official Debian archive

The self-hosted repository (see [README.md](README.md)) makes the packages
installable on Debian and Ubuntu today. This document is the playbook for the
second track: getting serialize, reliable, netcode and yojimbo into the
official Debian archive, so that a stock Debian or Ubuntu install can
`apt install` them with no repository setup at all.

## The process, end to end

For each source package:

1. **ITP bug** ("Intent To Package") filed against the `wnpp` pseudo-package
   (drafts below). This stakes out the package name and announces the plan on
   debian-devel.
2. **Package built and lintian-clean** — done, see below.
3. **Upload to [mentors.debian.net](https://mentors.debian.net)** and file an
   **RFS bug** ("Request For Sponsorship") — as upstream author you are the
   ideal maintainer, but a Debian Developer must sponsor the actual upload.
4. **NEW queue** — ftpmaster review (mainly licensing). Days to months,
   unpredictable.
5. **unstable → testing** — automatic migration after ~2–10 days if no release-
   critical bugs. The package ships in the *next* Debian stable (Debian 14
   "forky") and is backportable to current stable via `-backports` once in
   testing.
6. **Ubuntu** syncs from Debian unstable automatically: the packages appear in
   the first Ubuntu release whose import freeze they precede.

## Submission order

serialize, reliable and netcode are mutually independent — file and upload all
three **in parallel**. yojimbo `Build-Depends` on all three, so it can only be
uploaded **after they clear the NEW queue** into unstable. Have all four ready
upfront and pitch them to one sponsor as a coherent stack of small,
BSD-licensed libraries from a single upstream (the same order the Homebrew
submissions follow).

## What's already prepared

[`official/`](official/) holds the archive-ready packaging — distinct from
`packages/`, which serves the self-hosted repo:

- **Repacked orig tarballs.** `Files-Excluded` in `debian/copyright` strips
  the vendored code Debian Policy 4.13 objects to: netcode loses `sodium/`,
  yojimbo loses `netcode/ reliable/ serialize/ sodium/`; both become `+ds`
  versions and the watch files carry `repacksuffix=+ds`. **tlsf stays** — it
  is compiled into libyojimbo as a private implementation detail of the
  per-client allocators, is not packaged separately in Debian, and is
  documented in `debian/copyright`; be ready to justify this to ftpmaster.
- **autopkgtests** (`debian/tests/`): each package compiles (and, except
  header-only serialize, links and runs) a program against the installed
  package — Debian's CI runs these continuously once the packages are in.
- **DEP-12 upstream metadata** (`debian/upstream/metadata`).
- **CI validation**: the [`official`](.github/workflows/official.yml)
  workflow builds everything on `debian:sid` — full binary build (running the
  upstream test suites; yojimbo's must print `ALL TESTS PASS`), then a
  source-only build, then `lintian -I -E --pedantic --fail-on error` — and
  uploads sponsor-ready source packages as the `official-source-packages`
  artifact, lintian reports included.

Notes for sponsor conversations:

- **Static-only libraries** are acceptable for `-dev` packages but some
  sponsors prefer shared. If pressed: the CMake builds already set
  `VERSION`/`SOVERSION`, so `-DBUILD_SHARED_LIBS=ON` plus a split into
  `libyojimbo1`/`libyojimbo-dev` is mechanical. Static-first matches how game
  developers consume these libraries.
- The **`yojimbo` metapackage** (so `apt install yojimbo` works) is a
  convenience; drop it without argument if the sponsor or ftpmaster objects.
- **Names**: verified 2026-07-10 — the source names `serialize`, `reliable`,
  `netcode`, `yojimbo` and the binary names `libserialize-dev`,
  `libreliable-dev`, `libnetcode-dev`, `libyojimbo-dev`, `yojimbo` are all
  unclaimed in every Debian suite (sources.debian.org, packages.debian.org),
  and no WNPP bug claims any of them. `serialize` and `reliable` are still
  generic-sounding, so human feedback on the ITPs remains possible; treat a
  source-package rename (e.g. `mas-serialize`) as a cheap concession if
  asked.

## Submission runbook

One-time prerequisites (yours to do — they involve your identity and keys):

1. A **personal GPG key** (this is distinct from the apt-repo signing key in
   `keys/`), ideally RSA 4096 or ed25519, uploaded to keys.openpgp.org.
2. A **mentors.debian.net account** with that key registered.
3. On any Debian/Ubuntu machine (signing tools aren't on macOS):
   `apt install devscripts dput`, and add to `~/.dput.cf`:

   ```ini
   [mentors]
   fqdn = mentors.debian.net
   incoming = /upload
   method = https
   allow_dcut = 0
   progress_indicator = 2
   allowed_distributions = .*
   ```

Then, per wave:

1. **File the ITPs** (drafts below) by mailing `submit@bugs.debian.org` —
   all four the same day. The BTS replies with a bug number for each.
2. **Record the bug numbers** in [`official/itp.env`](official/itp.env) and
   push — the changelogs' `Closes:` lines pick them up.
3. **Run the `official` workflow** (it also runs on the push) and download
   the `official-source-packages` artifact. Review the `*.lintian.txt`
   reports.
4. **Wave 1 — serialize, reliable, netcode in parallel.** On your Debian box,
   for each:

   ```sh
   debsign <package>_<version>-1_source.changes
   dput mentors <package>_<version>-1_source.changes
   ```

   Then file an RFS bug per package (`reportbug sponsorship-requests`, or
   mail — mentors generates a template on the package page), noting the three
   are a set and that yojimbo follows.
5. **Wave 2 — yojimbo,** once all three have cleared NEW into unstable: same
   debsign/dput/RFS steps.
6. After acceptance, request **backports** to current stable if you want
   `apt install` to work there before Debian 14.

## ITP drafts

Send each as plain-text mail to `submit@bugs.debian.org` (or file with
`reportbug wnpp`). File all four the same day; cross-reference the bug numbers
in follow-ups.

### serialize

```
To: submit@bugs.debian.org
Subject: ITP: serialize -- header-only bitpacking serializer for C++

Package: wnpp
Severity: wishlist
Owner: Glenn Fiedler <glenn@mas-bandwidth.com>
X-Debbugs-Cc: debian-devel@lists.debian.org

* Package name    : serialize
  Version         : 1.4.3
  Upstream Author : Más Bandwidth LLC
* URL             : https://github.com/mas-bandwidth/serialize
* License         : BSD-3-Clause
  Programming Lang: C++
  Description     : header-only bitpacking serializer for C++

serialize is a simple bitpacking serializer for C++. A single templated
serialize function per object drives read, write and measure through the
same code path, making read/write mismatches structurally hard to write.
Values read from untrusted data are range-checked as they are decoded.

I am the upstream author. serialize is a build dependency of yojimbo, a
client/server network library for multiplayer games that I intend to
package next (together with its other dependencies, reliable and
netcode — ITPs filed separately). I will maintain the package and am
looking for a sponsor.
```

### reliable

```
To: submit@bugs.debian.org
Subject: ITP: reliable -- packet acknowledgement system for UDP protocols

Package: wnpp
Severity: wishlist
Owner: Glenn Fiedler <glenn@mas-bandwidth.com>
X-Debbugs-Cc: debian-devel@lists.debian.org

* Package name    : reliable
  Version         : 1.3.3
  Upstream Author : Más Bandwidth LLC
* URL             : https://github.com/mas-bandwidth/reliable
* License         : BSD-3-Clause
  Programming Lang: C
  Description     : packet acknowledgement system for UDP protocols

reliable is a simple packet acknowledgement system for UDP-based
protocols. It tells you which packets the other side received, measures
round trip time, packet loss and bandwidth, and fragments and
reassembles packets larger than MTU.

I am the upstream author. reliable is a build dependency of yojimbo, a
client/server network library for multiplayer games that I intend to
package next (together with its other dependencies, serialize and
netcode — ITPs filed separately). I will maintain the package and am
looking for a sponsor.
```

### netcode

```
To: submit@bugs.debian.org
Subject: ITP: netcode -- secure client/server connections over UDP

Package: wnpp
Severity: wishlist
Owner: Glenn Fiedler <glenn@mas-bandwidth.com>
X-Debbugs-Cc: debian-devel@lists.debian.org

* Package name    : netcode
  Version         : 1.3.3
  Upstream Author : Más Bandwidth LLC
* URL             : https://github.com/mas-bandwidth/netcode
* License         : BSD-3-Clause
  Programming Lang: C
  Description     : secure client/server connections over UDP

netcode is a protocol and library for creating encrypted and
authenticated client/server connections over UDP, designed for
real-time games. Clients authenticate with short-lived connect tokens
issued by a web backend, so game servers reject unauthenticated traffic
before allocating any per-client state. The Debian package links the
system libsodium; the vendored libsodium subset is stripped from the
source tarball.

I am the upstream author. netcode is a build dependency of yojimbo, a
client/server network library for multiplayer games that I intend to
package next (together with its other dependencies, serialize and
reliable — ITPs filed separately). I will maintain the package and am
looking for a sponsor.
```

### yojimbo

```
To: submit@bugs.debian.org
Subject: ITP: yojimbo -- client/server network library for multiplayer games

Package: wnpp
Severity: wishlist
Owner: Glenn Fiedler <glenn@mas-bandwidth.com>
X-Debbugs-Cc: debian-devel@lists.debian.org

* Package name    : yojimbo
  Version         : 1.6.1
  Upstream Author : Más Bandwidth LLC
* URL             : https://github.com/mas-bandwidth/yojimbo
* License         : BSD-3-Clause
  Programming Lang: C++
  Description     : client/server network library for multiplayer games

yojimbo is a network library for client/server games with dedicated
servers: encrypted and authenticated UDP connections (via netcode),
acks and packet fragmentation (via reliable), reliable-ordered and
unreliable-unordered message channels over a bitpacked serializer (via
serialize), and per-client memory silos so one client cannot starve
another. Encryption and authentication are on by default. Stable and
production ready, in use by shipped games for ten years.

Build-depends on libserialize-dev, libreliable-dev and libnetcode-dev
(ITPs filed separately); this upload follows their acceptance. The
vendored copies of those libraries and of libsodium are stripped from
the source tarball. I am the upstream author, will maintain the
package, and am looking for a sponsor.
```

## Finding a sponsor

- Upload each package to https://mentors.debian.net and file RFS bugs
  (`reportbug sponsorship-requests`), linking the four together.
- Mail debian-mentors@lists.debian.org introducing the stack — upstream
  author, ten years of history, fuzzed and sanitized CI, already packaged in
  a self-hosted apt repo and Homebrew.
- The **Debian Games Team** (debian-devel-games@lists.debian.org) is the
  natural home: game-engine libraries are their territory, team membership
  brings sponsors, and team-maintained packages outlive individual availability.

## Timeline expectations

Filing ITPs to acceptance in unstable: realistically a few months, dominated
by sponsor search and the NEW queue (twice — the three dependencies, then
yojimbo). After that: Ubuntu picks the packages up automatically in its next
release; Debian stable users get them in Debian 14 "forky", or earlier via
backports. The self-hosted repository covers everyone in the meantime.
