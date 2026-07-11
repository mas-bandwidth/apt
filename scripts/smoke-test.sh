#!/usr/bin/env bash
# End-to-end check that the packages installed by build-all.sh work from
# /usr: compile and link yojimbo's client and server samples against the
# installed headers and libraries, then run the server briefly.
#
# -DNDEBUG matches the packaged libraries, which are release builds.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/versions.env"
SRC="$REPO_ROOT/build/yojimbo/yojimbo-$YOJIMBO_VERSION"
TMP="$(mktemp -d)"

for app in client server; do
    g++ -DNDEBUG -O2 -o "$TMP/$app" "$SRC/$app.cpp" \
        -lyojimbo -lnetcode -lreliable -lsodium -lpthread -lm
    echo "smoke test: $app.cpp compiled and linked against installed packages"
done

# Liveness: the server must still be running after two seconds.
"$TMP/server" > /dev/null &
SERVER_PID=$!
sleep 2
kill "$SERVER_PID"   # fails (and fails the script) if the server died
echo "smoke test: server ran"

echo "SMOKE TEST PASS"
