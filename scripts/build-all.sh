#!/usr/bin/env bash
# Build all four packages in dependency order — serialize, reliable, netcode,
# yojimbo — installing each into the system as it is built (the later
# packages build against the earlier ones), and collect the .debs to publish
# into out/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$(dpkg --print-architecture)"

rm -rf "$REPO_ROOT/out"
mkdir -p "$REPO_ROOT/out"

for name in serialize reliable netcode yojimbo; do
    "$REPO_ROOT/scripts/build-package.sh" "$name"

    # Install what was just built; later packages in the chain need it.
    # This also exercises every package's own install, including the
    # yojimbo metapackage.
    apt-get install -y "$REPO_ROOT"/build/"$name"/*.deb

    # Publish all debs from the amd64 build; only the arch-specific debs
    # from other architectures (their arch-all debs are local-only
    # duplicates and would collide in the apt repo pool).
    if [ "$ARCH" = "amd64" ]; then
        cp "$REPO_ROOT"/build/"$name"/*.deb "$REPO_ROOT/out/"
    else
        cp "$REPO_ROOT"/build/"$name"/*_"$ARCH".deb "$REPO_ROOT/out/"
    fi
done

ls -l "$REPO_ROOT/out"
