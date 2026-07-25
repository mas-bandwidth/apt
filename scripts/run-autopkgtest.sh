#!/usr/bin/env bash
# Run the real autopkgtest suite for the named official-track packages against
# the binary packages scripts/build-official.sh produced. With no arguments,
# runs all four.
#
#   ./scripts/run-autopkgtest.sh            # all four, one after another
#   ./scripts/run-autopkgtest.sh yojimbo    # just one
#
# The workflow passes one package per job so that each gets a container of its
# own. That matters: the null runner cannot revert what a test installs, so
# running all four in one container would leave the second package onwards
# testing against a testbed already carrying the previous package's test
# dependencies — build-essential would always be present by then, and a
# debian/tests/control that forgot to depend on it would still pass.
#
# Until this existed, official/*/debian/tests/ had never been executed by
# anything: the official workflow built the source packages and ran lintian,
# which does not run tests, so the test scripts were shipped to a sponsor
# unexercised. Debian's own CI would have been the first thing to run them.
#
# Run inside a debian:sid container with autopkgtest and dpkg-dev installed —
# this is what the "autopkgtest" job of the official workflow does. Input is
# out-official-binaries/, produced by build-official.sh.
#
# THE TESTBED IS THIS MACHINE. autopkgtest's "null" virt server "does not
# actually offer any kind of separation between host and testbed": it runs the
# tests directly here, installs each test's Depends into the running system,
# and cannot revert any of it afterwards. That is fine in a throwaway CI
# container and is why the workflow job runs in one; do not run this on a
# machine you care about.
# The alternatives were considered and rejected for CI use: schroot/lxc/qemu
# all want to build a testbed image first (sbuild-createchroot, autopkgtest-
# build-lxc, autopkgtest-build-qemu), which needs privileges a container job
# does not have and adds several minutes to every run; the docker/podman
# runners need a working container daemon inside the container. "null" in a
# disposable sid container gets the test scripts genuinely executed, which is
# the entire point, without any of that.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO_ROOT/out-official-binaries"
OUT="$REPO_ROOT/out-autopkgtest"
LOCAL_REPO="$OUT/local-apt-repo"

ALL_PACKAGES=(serialize reliable netcode yojimbo)
PACKAGES=("$@")
[ "${#PACKAGES[@]}" -gt 0 ] || PACKAGES=("${ALL_PACKAGES[@]}")
for want in "${PACKAGES[@]}"; do
    case " ${ALL_PACKAGES[*]} " in
        *" $want "*) ;;
        *) echo "error: unknown package '$want'" >&2; exit 1 ;;
    esac
done

command -v autopkgtest >/dev/null 2>&1 || {
    echo "error: autopkgtest is not installed (apt-get install autopkgtest)" >&2
    exit 1
}
[ -d "$BIN" ] || {
    echo "error: $BIN not found — run scripts/build-official.sh first" >&2
    exit 1
}

rm -rf "$OUT"
mkdir -p "$OUT" "$LOCAL_REPO"

echo "=== packages under test ==="
ls -l "$BIN"
echo

# yojimbo Depends on libserialize-dev, libreliable-dev and libnetcode-dev,
# none of which are in the Debian archive yet — that is what the ITPs are for.
# Serving all four packages' .debs from a local apt repository is what lets apt
# satisfy that chain inside a testbed that has never seen the other three. It
# stands in for the archive the packages will live in once accepted; see the
# coverage caveats in DEBIAN.md.
cp "$BIN"/*.deb "$LOCAL_REPO/"
(
    cd "$LOCAL_REPO"
    dpkg-scanpackages -m . > Packages
    # Packages.gz and a Release file are not strictly needed for a flat
    # [trusted=yes] repository, but without them apt probes for every
    # compression variant in turn and fills the log with read errors.
    gzip -9kf Packages
    apt-ftparchive release . > Release
)
echo "deb [trusted=yes] file://$LOCAL_REPO ./" \
    > /etc/apt/sources.list.d/mas-bandwidth-autopkgtest-local.list
apt-get update

# autopkgtest(1) EXIT STATUS. Only 0 is a pass here: a skipped test has not
# run, and "no tests" means debian/tests/ went missing, both of which are the
# failure this script exists to catch.
describe_rc() {
    case "$1" in
        0)  echo "all tests passed" ;;
        2)  echo "at least one test was skipped, or a flaky test failed" ;;
        4)  echo "at least one test FAILED" ;;
        6)  echo "at least one test failed and at least one was skipped" ;;
        8)  echo "no tests in this package, or all non-superficial tests skipped" ;;
        12) echo "erroneous package" ;;
        14) echo "erroneous package and at least one test skipped" ;;
        16) echo "failure to open, close or communicate with the testbed" ;;
        20) echo "other unexpected failure, including bad usage" ;;
        *)  echo "undocumented autopkgtest exit code" ;;
    esac
}

failed=()
for name in "${PACKAGES[@]}"; do
    changes=("$BIN/${name}_"*.changes)
    [ "${#changes[@]}" -eq 1 ] && [ -f "${changes[0]}" ] || {
        echo "error: expected exactly one .changes for $name in $BIN," \
             "found: ${changes[*]}" >&2
        exit 1
    }

    echo
    echo "================================================================"
    echo "=== autopkgtest: $name ($(basename "${changes[0]}"))"
    echo "================================================================"

    # -B: test the binaries built by build-official.sh rather than rebuilding
    # them from source. The .changes carries both the .debs and the .dsc whose
    # debian/tests/ is under test.
    rc=0
    autopkgtest \
        --no-built-binaries \
        --output-dir "$OUT/$name" \
        --summary "$OUT/$name.summary" \
        "${changes[0]}" \
        -- null || rc=$?

    # The per-test stdout is the proof the test script actually ran, so print
    # it rather than trusting the exit status alone.
    for f in "$OUT/$name"/*-stdout "$OUT/$name"/*-stderr; do
        [ -s "$f" ] || continue
        echo "--- $name: $(basename "$f") ---"
        cat "$f"
    done
    if [ -s "$OUT/$name.summary" ]; then
        echo "--- $name: summary ---"
        cat "$OUT/$name.summary"
    fi

    echo "=== $name: autopkgtest exit $rc ($(describe_rc "$rc"))"
    if [ "$rc" -eq 8 ]; then
        echo "note: a test marked 'Restrictions: superficial' does not count as"
        echo "      a test. If every test in a package is superficial then it"
        echo "      has no non-superficial tests, autopkgtest exits 8, and"
        echo "      Debian's CI treats the package as untested however green"
        echo "      the individual result looks. Deepen the test or drop the"
        echo "      restriction."
    fi
    [ "$rc" -eq 0 ] || failed+=("$name (exit $rc)")
done

echo
echo "================================================================"
if [ "${#failed[@]}" -gt 0 ]; then
    echo "autopkgtest FAILED for: ${failed[*]}"
    exit 1
fi
echo "autopkgtest passed: ${PACKAGES[*]}"
