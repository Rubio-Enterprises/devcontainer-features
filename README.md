# devcontainer-features

Dev Container Features for Rubio-Enterprises repositories, published to GHCR.

## baseline

`ghcr.io/rubio-enterprises/devcontainer-features/baseline` is the shared setup
every Rubio-Enterprises Dev Container carries. A repository's
`.devcontainer/devcontainer.json` needs only the upstream base image and this
feature, pinned to an exact version:

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:2.2.1-trixie",
  "features": {
    "ghcr.io/rubio-enterprises/devcontainer-features/baseline:1.1.0": {}
  }
}
```

It provides:

- **mise and the GitHub CLI**, through `dependsOn` on
  `ghcr.io/devcontainers-extra/features/mise:1` and
  `ghcr.io/devcontainers/features/github-cli:1`. The base image already ships
  git, and each repository's mise configuration installs the rest of its tools.
- **mise's shims on `PATH`** for every process in the container: terminals,
  lifecycle commands, VS Code tasks, `devcontainer exec`, and a plain
  `docker exec`. A tool from the repository's mise configuration therefore runs
  by name, without `mise exec --` or `mise activate`. `MISE_SHIMS_DIR` moves the
  shims to `/usr/local/share/mise-shims`, owned by the remote user, so the
  static `PATH` entry does not depend on a home directory. Shims apply a
  repository's mise `[env]` only to the tool they launch; use `mise run` or
  `mise exec --` where a command needs those variables.
- **`DOTFILES_PROFILE=personal`**, which the dotfiles installer reads to choose
  the personal profile. Only Rubio-Enterprises repositories use this feature, so
  every other repository falls back to the installer's work default.
- **git `safe.directory` for `/workspaces/*`**, set through
  `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_0`/`GIT_CONFIG_VALUE_0`. Bind-mounted
  checkouts can report a foreign owner, and git then refuses to work in them.
  git honors `safe.directory` from these variables because they are
  command-scope configuration.

It does not install dotfiles. The Dev Container client does that: VS Code's
`dotfiles.repository` setting, which Settings Sync does not sync, or the
CLI's `--dotfiles-repository`.

## Test

```bash
devcontainer features test --features baseline \
  --base-image mcr.microsoft.com/devcontainers/base:2.2.1-trixie --skip-scenarios \
  --remote-user root .
```

The tests run as root because they create repositories owned by another user, and they need a Docker daemon. CI runs them in `.github/workflows/test.yaml`.

## Release

Bump `version` in `src/<feature>/devcontainer-feature.json` in the same pull
request as the change. On merge, `.github/workflows/release.yaml` publishes
every feature whose version is not in GHCR yet, tagged `MAJOR`,
`MAJOR.MINOR`, `MAJOR.MINOR.PATCH`, and `latest`. Consumers pin the exact
version, and Renovate's devcontainer manager proposes updates.
