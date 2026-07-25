<!-- HOT:BEGIN -->
WHAT: Debian packaging ONLY for serialize/reliable/netcode/yojimbo, plus the signed unofficial apt
repo at mas-bandwidth.github.io/apt. No library source here; fetched by tag at build time
from mas-bandwidth/{serialize,reliable,netcode,yojimbo}.

TWO TREES, divergent on purpose. `packages/` = unofficial repo (debhelper-compat 13, S-V 4.7.0,
explicit ${misc:Depends}, watch v4, no repack). `official/` = Debian archive track (compat 14,
S-V 4.7.4, watch v5, +ds repack). Edit the right one.

DECISIONS (not bugs, not backlog)
- yojimbo is WAVE 2 by decision: it Build-Depends on the other three, so it can only be uploaded
  after they clear NEW into unstable.
- official/ omits Priority, Rules-Requires-Root and ${misc:Depends} deliberately: lintian polish
  (9291c53), then sponsor review (557d3b9 - compat 14 appends ${misc:Depends}). Do not re-add.
- tlsf stays vendored and compiled into libyojimbo, a private allocator detail. Files-Excluded
  strips only sodium (netcode) and netcode/reliable/serialize/sodium (yojimbo) -> +ds.
- Static-only -dev is deliberate. The shared-lib split (BUILD_SHARED_LIBS, libyojimbo1) is a
  concession held in reserve for a sponsor, not a gap.
- Never vendor: NETCODE_SYSTEM_SODIUM=ON, YOJIMBO_SYSTEM_DEPS=ON, so distro security fixes flow.

INVARIANT: SOURCE names are plain (serialize reliable netcode yojimbo); BINARY names are lib*-dev,
plus a `yojimbo` metapackage present in BOTH trees. Never mix the two levels.

TRAPS
- Homebrew core's formula is `libyojimbo`; Debian's source is plain `yojimbo`. Look names up.
- build.yml ignores official/** and **.md; official.yml fires only on official/**, versions.env,
  scripts/build-official.sh. Wrong tree = wrong workflow, or none.
- ITP numbers live in official/itp.env; unset -> changelog closes #XXXXXX and submit-to-mentors.sh
  refuses.

NEVER file yojimbo's RFS before wave 1 is in unstable. NEVER commit the signing secret: keys/ holds
the PUBLIC key only, the private half is the APT_SIGNING_KEY repo secret.
<!-- HOT:END -->

## Build and test

Requires Debian or Ubuntu (build-essential, debhelper, cmake, libsodium-dev, devscripts).

- `./scripts/build-all.sh` builds all four packages in dependency order into `out/`, installing
  each as it goes. Run by build.yml inside each distro container.
- `./scripts/smoke-test.sh` compiles and runs yojimbo's samples against the installed packages.
- `./scripts/build-package.sh <serialize|reliable|netcode|yojimbo>` builds one package.
- `./scripts/build-official.sh` builds and lintian-validates the official-track source packages
  into `out-official/`. Run by official.yml on `debian:sid`.
- `./scripts/check-releases.sh [--update]` compares versions.env against the latest upstream
  releases.

Layout: `packages/` and `official/` hold the two packaging trees, `scripts/` the build and
submission helpers, `itp/` the ITP mail drafts, `keys/` the public signing key.
See README.md for the apt repo, DEBIAN.md for the Debian archive track.
