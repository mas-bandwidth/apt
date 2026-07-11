#!/usr/bin/env bash
# Assemble and sign the apt repository from CI build artifacts.
#
#   usage: make-apt-repo.sh <incoming-dir> <site-dir>
#
# <incoming-dir> holds one subdirectory per build job, named
# debs-<codename>-<arch> and containing .deb files. <site-dir> is emptied
# and receives the publishable repository (dists/ + pool/ + public key).
# Requires reprepro, and the signing secret key already imported into gpg.
set -euo pipefail

IN="${1:?usage: make-apt-repo.sh <incoming-dir> <site-dir>}"
SITE="${2:?usage: make-apt-repo.sh <incoming-dir> <site-dir>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${BASE_URL:-https://mas-bandwidth.github.io/apt}"

KEYID="${KEYID:-$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/ {print $5; exit}')}"
[ -n "$KEYID" ] || { echo "error: no gpg secret key available for signing" >&2; exit 1; }

DISTS="$(ls "$IN" | sed -n 's/^debs-\(.*\)-\(amd64\|arm64\)$/\1/p' | sort -u)"
[ -n "$DISTS" ] || { echo "error: no debs-<codename>-<arch> directories in $IN" >&2; exit 1; }

rm -rf "$SITE"
mkdir -p "$SITE/conf"

for dist in $DISTS; do
    cat >> "$SITE/conf/distributions" <<EOF
Origin: mas-bandwidth
Label: mas-bandwidth
Codename: $dist
Architectures: amd64 arm64
Components: main
Description: yojimbo, netcode, reliable and serialize packages
SignWith: $KEYID

EOF
done

for dist in $DISTS; do
    reprepro -b "$SITE" includedeb "$dist" "$IN"/debs-"$dist"-*/*.deb
done

# Only dists/ and pool/ are served; reprepro's working state is not.
rm -rf "$SITE/db" "$SITE/conf"

if [ -f "$REPO_ROOT/keys/mas-bandwidth-apt.asc" ]; then
    cp "$REPO_ROOT/keys/mas-bandwidth-apt.asc" "$SITE/"
else
    echo "warning: keys/mas-bandwidth-apt.asc not found — repo is signed but the public key is not published" >&2
fi

cat > "$SITE/index.html" <<EOF
<!doctype html>
<title>mas-bandwidth apt repository</title>
<h1>mas-bandwidth apt repository</h1>
<p>Debian and Ubuntu packages for
<a href="https://github.com/mas-bandwidth/yojimbo">yojimbo</a>,
<a href="https://github.com/mas-bandwidth/netcode">netcode</a>,
<a href="https://github.com/mas-bandwidth/reliable">reliable</a> and
<a href="https://github.com/mas-bandwidth/serialize">serialize</a>.</p>
<pre>
sudo install -d /etc/apt/keyrings
sudo curl -fsSL $BASE_URL/mas-bandwidth-apt.asc -o /etc/apt/keyrings/mas-bandwidth-apt.asc
echo "deb [signed-by=/etc/apt/keyrings/mas-bandwidth-apt.asc] $BASE_URL \$(. /etc/os-release &amp;&amp; echo \$VERSION_CODENAME) main" | sudo tee /etc/apt/sources.list.d/mas-bandwidth.list
sudo apt update
sudo apt install yojimbo
</pre>
<p>Suites: $(echo $DISTS | tr '\n' ' ')</p>
EOF

echo "apt repository written to $SITE for dists: $(echo $DISTS | tr '\n' ' ')"
