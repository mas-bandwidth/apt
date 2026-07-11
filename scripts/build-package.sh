#!/usr/bin/env bash
# Build one package's .debs from its GitHub release tarball.
#
#   usage: build-package.sh <serialize|reliable|netcode|yojimbo>
#
# Reads the pinned upstream version from versions.env. Must run on Debian or
# Ubuntu with build-essential, debhelper, cmake and libsodium-dev installed,
# and (for netcode/yojimbo) the earlier packages in the dependency chain
# already installed — see build-all.sh, which drives this in order.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?usage: build-package.sh <package-name>}"

source "$REPO_ROOT/versions.env"
VAR="$(echo "$NAME" | tr '[:lower:]' '[:upper:]')_VERSION"
VERSION="${!VAR:?unknown package $NAME}"

# Per-distro version suffix (the convention PPAs use), so each dist in the
# apt repo references distinct pool files: e.g. 1.6.1-1~bookworm1.
DIST="${DIST:-$(. /etc/os-release && echo "$VERSION_CODENAME")}"
DEBVER="$VERSION-1~${DIST}1"

WORK="$REPO_ROOT/build/$NAME"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

# GitHub release tarballs extract to <name>-<version>/, which is exactly the
# layout dpkg wants next to <name>_<version>.orig.tar.gz.
curl -fsSL --retry 3 \
    "https://github.com/mas-bandwidth/$NAME/archive/refs/tags/v$VERSION.tar.gz" \
    -o "${NAME}_${VERSION}.orig.tar.gz"
tar xzf "${NAME}_${VERSION}.orig.tar.gz"
cd "$NAME-$VERSION"
cp -a "$REPO_ROOT/packages/$NAME/debian" debian

cat > debian/changelog <<EOF
$NAME ($DEBVER) $DIST; urgency=medium

  * Automated package build of upstream release v$VERSION.

 -- Glenn Fiedler <glenn@mas-bandwidth.com>  $(date -R)
EOF

# Full binary build everywhere (-b): non-amd64 architectures also build the
# Architecture: all packages because they are needed locally as build
# dependencies further down the chain — build-all.sh only *publishes*
# arch-all debs from the amd64 build.
dpkg-buildpackage -us -uc -b
