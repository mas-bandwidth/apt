#!/usr/bin/env bash
# Install the pinned Go toolchain (versions.env: SCHEMA_GO_*) into
# /usr/local/go, for building the schema package. The official tarball is
# fetched from go.dev and verified against the pinned per-arch sha256.
#
# Run as root (the CI containers are). Inside GitHub Actions the step also
# gets /usr/local/go/bin onto the PATH of subsequent steps; anywhere else,
# export PATH=/usr/local/go/bin:$PATH yourself.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/versions.env"

case "$(dpkg --print-architecture)" in
    amd64) GOARCH=amd64; SHA256="$SCHEMA_GO_SHA256_AMD64" ;;
    arm64) GOARCH=arm64; SHA256="$SCHEMA_GO_SHA256_ARM64" ;;
    *) echo "error: no pinned Go toolchain for $(dpkg --print-architecture)" >&2; exit 1 ;;
esac

TARBALL="go${SCHEMA_GO_VERSION}.linux-${GOARCH}.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL --retry 3 "https://go.dev/dl/$TARBALL" -o "$TMP/$TARBALL"
echo "$SHA256  $TMP/$TARBALL" | sha256sum -c -

rm -rf /usr/local/go
tar -C /usr/local -xzf "$TMP/$TARBALL"

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "/usr/local/go/bin" >> "$GITHUB_PATH"
fi

/usr/local/go/bin/go version
