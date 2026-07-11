#!/usr/bin/env bash
# One-time setup: generate the apt repository signing key.
#
# Writes:
#   keys/mas-bandwidth-apt.asc      the PUBLIC key — check this in
#   apt-signing-key.secret.asc      the PRIVATE key — gitignored, never commit
#
# The key is generated in a throwaway GNUPGHOME so your personal gpg keyring
# is untouched, and that keyring is deleted when this script exits: the
# exported .secret.asc file is then the ONLY copy of the private key.
# Back it up somewhere safe (e.g. your password manager) before deleting it.
set -euo pipefail

command -v gpg >/dev/null || { echo "error: gpg not found (macOS: brew install gnupg)" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UID_STR="Más Bandwidth apt repository <glenn@mas-bandwidth.com>"
SECRET="$REPO_ROOT/apt-signing-key.secret.asc"
PUBLIC="$REPO_ROOT/keys/mas-bandwidth-apt.asc"

[ ! -f "$SECRET" ] || { echo "error: $SECRET already exists — refusing to overwrite" >&2; exit 1; }
[ ! -f "$PUBLIC" ] || { echo "error: $PUBLIC already exists — refusing to overwrite" >&2; exit 1; }

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

# No passphrase: CI signs unattended. No expiry: apt repo keys are rotated
# deliberately, not on a timer.
gpg --batch --quick-generate-key "$UID_STR" ed25519 sign never

gpg --armor --export > "$PUBLIC"
gpg --armor --export-secret-keys > "$SECRET"
chmod 600 "$SECRET"

cat <<EOF

Signing key generated.

  public key : $PUBLIC   (commit this)
  private key: $SECRET   (gitignored — NEVER commit)

Next steps, in order:

  1. Back up the private key somewhere safe (password manager / offline).
     This file is now the only copy in existence.

  2. Upload it to the GitHub Actions secret the publish workflow uses:

       gh secret set APT_SIGNING_KEY --repo mas-bandwidth/apt < "$SECRET"

  3. Delete the local file:

       rm "$SECRET"
EOF
