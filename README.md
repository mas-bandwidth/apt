# mas-bandwidth apt repository

Debian and Ubuntu packages for [yojimbo](https://github.com/mas-bandwidth/yojimbo),
[netcode](https://github.com/mas-bandwidth/netcode),
[reliable](https://github.com/mas-bandwidth/reliable) and
[serialize](https://github.com/mas-bandwidth/serialize).

This repository holds the `debian/` packaging for all four libraries and the CI
pipeline that builds them and publishes a signed apt repository to GitHub Pages.
(For getting the packages into the official Debian archive, see [DEBIAN.md](DEBIAN.md).)

## Installing the packages

One-time repository setup:

```sh
sudo install -d /etc/apt/keyrings
sudo curl -fsSL https://mas-bandwidth.github.io/apt/mas-bandwidth-apt.asc \
    -o /etc/apt/keyrings/mas-bandwidth-apt.asc
echo "deb [signed-by=/etc/apt/keyrings/mas-bandwidth-apt.asc] https://mas-bandwidth.github.io/apt $(. /etc/os-release && echo $VERSION_CODENAME) main" \
    | sudo tee /etc/apt/sources.list.d/mas-bandwidth.list
sudo apt update
```

Then:

```sh
sudo apt install yojimbo
```

`yojimbo` is a metapackage that pulls in `libyojimbo-dev` and the full dependency
chain. The individual packages:

| Package           | Contents                                                       |
|-------------------|----------------------------------------------------------------|
| `libyojimbo-dev`  | client/server game network library (static lib + headers)      |
| `libnetcode-dev`  | encrypted, authenticated UDP connections (static lib + header) |
| `libreliable-dev` | acks and packet fragmentation (static lib + header + .pc file) |
| `libserialize-dev`| header-only bitpacking serializer                              |
| `yojimbo`         | metapackage: installs `libyojimbo-dev`                         |

Supported: Debian 12 (bookworm), Debian 13 (trixie), Ubuntu 22.04 (jammy),
Ubuntu 24.04 (noble), Ubuntu 26.04 — amd64 and arm64.

### Using the packages

```sh
g++ -DNDEBUG -O2 -o game game.cpp -lyojimbo -lnetcode -lreliable -lsodium -lpthread -lm
```

The packaged libraries are release builds (`NDEBUG`), matching yojimbo's design
contract: validate your integration in a debug build first, then ship release.
For debug-mode development, build yojimbo from source — the source tree is
self-contained and needs no dependencies.

## How it works

- [`versions.env`](versions.env) pins the upstream release of each library.
- [`packages/*/debian/`](packages/) holds the packaging for each library.
  Packages are built from the upstream GitHub release tarballs against the
  distro libsodium (`NETCODE_SYSTEM_SODIUM=ON`) and against each other
  (`YOJIMBO_SYSTEM_DEPS=ON`); nothing vendored is compiled in except tlsf,
  which is a private implementation detail of yojimbo's per-client allocators.
- [`build.yml`](.github/workflows/build.yml) builds every distro × arch in
  containers, runs each package's test suite during the build (yojimbo's full
  functional test suite must print `ALL TESTS PASS`), smoke-tests the installed
  packages by compiling and running the yojimbo samples against them, then
  assembles, signs and deploys the repository to GitHub Pages. PR builds
  validate but do not publish.
- [`check-releases.yml`](.github/workflows/check-releases.yml) runs daily and
  opens a bump PR when any of the four upstreams publishes a new release.

## Maintainer: one-time setup

1. Create the GitHub repository and push:

   ```sh
   cd ~/apt
   git add -A && git commit -m "apt repository packaging and CI"
   gh repo create mas-bandwidth/apt --public --source . --push
   ```

2. Generate the signing key and store it (full instructions printed by the script):

   ```sh
   ./scripts/generate-signing-key.sh
   gh secret set APT_SIGNING_KEY --repo mas-bandwidth/apt < apt-signing-key.secret.asc
   git add keys/mas-bandwidth-apt.asc && git commit -m "Add repository public signing key" && git push
   ```

3. In the repository settings on GitHub:
   - **Pages** → Source: **GitHub Actions**.
   - **Actions → General** → allow GitHub Actions to **create and approve pull
     requests** (used by the daily release-check workflow).

4. Run the **build** workflow (Actions tab → build → Run workflow). When it
   finishes, the repository is live at
   `https://mas-bandwidth.github.io/apt`.

Optional: serve from `apt.mas-bandwidth.com` by adding a CNAME in Pages
settings and a DNS CNAME record to `mas-bandwidth.github.io`, then set
`BASE_URL` in the publish step accordingly.

## Releasing updates

Nothing to do: when a new release of any library is published on GitHub, the
daily check opens a bump PR; merging it rebuilds and republishes everything.
To force it, edit `versions.env` and push, or run the build workflow manually.
