#!/usr/bin/env bash
# Sign and upload the official-track source packages to mentors.debian.net.
#
#   usage: submit-to-mentors.sh wave1|wave2
#
#   wave1 = serialize, reliable, netcode   (mutually independent)
#   wave2 = yojimbo                        (only after wave1 clears NEW)
#
# Run this on a Debian/Ubuntu machine (not macOS) with:
#   - your personal GPG key available to gpg (debsign uses it)
#   - a mentors.debian.net account with that key registered
#   - gh (authenticated), devscripts and dput installed
#   - [mentors] configured in ~/.dput.cf              (see DEBIAN.md)
#
# It downloads the latest successful official-source-packages artifact,
# refuses to continue if the changelogs still carry the ITP placeholder
# (fill official/itp.env and re-run the official workflow first), then
# debsigns and dputs each package in the wave.
set -euo pipefail

WAVE="${1:?usage: submit-to-mentors.sh wave1|wave2}"
case "$WAVE" in
    wave1) PKGS="serialize reliable netcode" ;;
    wave2) PKGS="yojimbo" ;;
    *) echo "error: unknown wave '$WAVE' (use wave1 or wave2)" >&2; exit 1 ;;
esac

for tool in gh debsign dput; do
    command -v "$tool" >/dev/null || {
        echo "error: $tool not found (apt install gh devscripts dput)" >&2; exit 1; }
done

RUN="$(gh run list --repo mas-bandwidth/apt --workflow official \
      --status success --limit 1 --json databaseId --jq '.[0].databaseId')"
[ -n "$RUN" ] || { echo "error: no successful 'official' workflow run found" >&2; exit 1; }

WORK="$(mktemp -d)"
echo "downloading official-source-packages from run $RUN to $WORK"
gh run download "$RUN" --repo mas-bandwidth/apt \
    --name official-source-packages --dir "$WORK"
cd "$WORK"

for p in $PKGS; do
    changes="$(ls "${p}"_*_source.changes)"
    if grep -q "XXXXXX" "$changes"; then
        echo "error: $p changelog still closes placeholder bug #XXXXXX." >&2
        echo "File the ITP, put the bug number in official/itp.env, push, and" >&2
        echo "let the 'official' workflow rebuild before uploading." >&2
        exit 1
    fi
done

for p in $PKGS; do
    changes="$(ls "${p}"_*_source.changes)"
    echo "=== $p: signing $changes"
    debsign "$changes"
    echo "=== $p: uploading to mentors"
    dput mentors "$changes"
done

echo
echo "Done. Next: file an RFS bug per package (templates in DEBIAN.md);"
echo "mentors also shows a ready-made RFS template on each package page."
