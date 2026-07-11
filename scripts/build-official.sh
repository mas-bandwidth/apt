#!/usr/bin/env bash
# Build the OFFICIAL-Debian-track source packages for all four libraries on
# Debian unstable, validate each with a full binary build (which runs the
# upstream test suites) and lintian, and collect sponsor-ready source
# packages into out-official/.
#
# Run inside a debian:sid container with build-essential, debhelper, cmake,
# libsodium-dev, devscripts and lintian installed — this is what the
# "official" GitHub Actions workflow does.
#
# The resulting *_source.changes files are unsigned: signing (debsign) and
# uploading to mentors.debian.net (dput) are done by the maintainer — see
# DEBIAN.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/out-official"

source "$REPO_ROOT/versions.env"
source "$REPO_ROOT/official/itp.env"

rm -rf "$OUT"
mkdir -p "$OUT"

for name in serialize reliable netcode yojimbo; do
    UPPER="$(echo "$name" | tr '[:lower:]' '[:upper:]')"
    VERSION_VAR="${UPPER}_VERSION"
    ITP_VAR="${UPPER}_ITP"
    VERSION="${!VERSION_VAR:?unknown package $name}"
    ITP="${!ITP_VAR:-}"
    if [ -z "$ITP" ]; then
        ITP="XXXXXX"
        echo "WARNING: $ITP_VAR is not set in official/itp.env — the changelog" \
             "will close placeholder bug #XXXXXX. File the ITP first (DEBIAN.md)." >&2
    fi

    WORK="$REPO_ROOT/build-official/$name"
    rm -rf "$WORK"
    mkdir -p "$WORK"
    cd "$WORK"

    curl -fsSL --retry 3 \
        "https://github.com/mas-bandwidth/$name/archive/refs/tags/v$VERSION.tar.gz" \
        -o "$name-$VERSION.github.tar.gz"

    # mk-origtargz applies Files-Excluded from debian/copyright: netcode and
    # yojimbo lose their vendored code and gain a +ds suffix; serialize and
    # reliable exclude nothing, so no suffix is added and the tarball is
    # simply recompressed as the .orig.tar.xz.
    mk-origtargz --package "$name" --version "$VERSION" \
        --repack --repack-suffix '+ds' --compression xz \
        --copyright-file "$REPO_ROOT/official/$name/debian/copyright" \
        --directory . "$name-$VERSION.github.tar.gz"

    if [ -f "${name}_${VERSION}+ds.orig.tar.xz" ]; then
        UV="$VERSION+ds"
    else
        UV="$VERSION"
    fi
    ORIG="${name}_${UV}.orig.tar.xz"
    [ -f "$ORIG" ] || { echo "error: expected $ORIG after mk-origtargz" >&2; exit 1; }

    # The source tree must be unpacked from the REPACKED tarball, so the
    # excluded directories are absent from both sides of the dpkg-source diff.
    SRCDIR="$name-$UV"
    mkdir "$SRCDIR"
    tar xf "$ORIG" -C "$SRCDIR" --strip-components=1
    cp -a "$REPO_ROOT/official/$name/debian" "$SRCDIR/debian"

    cat > "$SRCDIR/debian/changelog" <<EOF
$name ($UV-1) unstable; urgency=medium

  * Initial release. (Closes: #$ITP)

 -- Glenn Fiedler <glenn@mas-bandwidth.com>  $(date -R)
EOF

    cd "$SRCDIR"

    # Full build: proves the package builds on sid and runs the upstream
    # test suites (dh_auto_test / yojimbo's bin/test).
    dpkg-buildpackage -us -uc

    # Source-only build: what actually gets signed and uploaded to mentors.
    dpkg-buildpackage -S -us -uc

    cd "$WORK"
    lintian -I -E --pedantic --fail-on error \
        "${name}_${UV}-1_"*.changes | tee "$OUT/$name.lintian.txt" || {
            echo "error: lintian found errors for $name (see above)" >&2
            exit 1
        }

    # Later packages in the chain build against the ones just built.
    apt-get install -y "$WORK"/*.deb

    cp "$ORIG" "${name}_${UV}-1.debian.tar.xz" "${name}_${UV}-1.dsc" \
       "${name}_${UV}-1_source.changes" "$OUT/"
done

echo
echo "Sponsor-ready source packages in $OUT:"
ls -l "$OUT"
