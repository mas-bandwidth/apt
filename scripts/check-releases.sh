#!/usr/bin/env bash
# Compare the pinned versions in versions.env against the latest GitHub
# releases of the four upstream repositories.
#
#   usage: check-releases.sh [--update]
#
# Prints anything out of date. With --update, also rewrites versions.env
# with the latest versions. Exits 1 if anything was out of date (so CI can
# branch on it), 0 if everything is current.
# Requires the gh CLI (GH_TOKEN in CI).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1

source "$REPO_ROOT/versions.env"

stale=0
for name in serialize reliable netcode yojimbo; do
    var="$(echo "$name" | tr '[:lower:]' '[:upper:]')_VERSION"
    pinned="${!var}"
    latest="$(gh api "repos/mas-bandwidth/$name/releases/latest" --jq .tag_name)"
    latest="${latest#v}"
    if [ "$pinned" != "$latest" ]; then
        echo "$name: pinned $pinned, latest $latest"
        stale=1
        if [ "$UPDATE" = 1 ]; then
            sed -i.bak "s/^$var=.*/$var=$latest/" "$REPO_ROOT/versions.env"
            rm -f "$REPO_ROOT/versions.env.bak"
        fi
    fi
done

[ "$stale" = 0 ] && echo "all pinned versions are current"
exit "$stale"
