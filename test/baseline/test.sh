#!/bin/bash
set -e

# Runs against the auto-generated devcontainer.json that includes the
# 'baseline' feature with no options, as root (--remote-user root): the
# safe.directory checks create repositories owned by another user. See
# https://github.com/devcontainers/cli/blob/main/docs/features/test.md
# The Dev Container CLI puts this library on PATH inside the test container.
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "mise is installed" mise --version
check "gh is installed" gh --version
check "dotfiles install selects the personal profile" test "$DOTFILES_PROFILE" = personal

# git refuses repositories owned by another user unless safe.directory lists
# them. Bind-mounted checkouts can report a foreign owner, so the feature marks
# everything under /workspaces safe, and nothing else.
make_foreign_repo() {
  mkdir -p "$1" && git init -q "$1" && chown -R 12345:12345 "$1"
}
make_foreign_repo /workspaces/foreign-owner
make_foreign_repo /tmp/foreign-owner
check "git trusts a foreign-owned repo under /workspaces" git -C /workspaces/foreign-owner rev-parse --git-dir
check "git still refuses a foreign-owned repo elsewhere" bash -c '! git -C /tmp/foreign-owner rev-parse --git-dir'

# A tool from mise configuration runs by name, with no `mise activate` or
# `mise exec --`: plain `docker exec`, lifecycle commands, and tasks see only
# the container environment. A linked fake keeps the check offline; the base
# image ships no node.
mkdir -p /tmp/fake-node/bin
printf '#!/bin/sh\necho fake-node\n' >/tmp/fake-node/bin/node
chmod +x /tmp/fake-node/bin/node
mise link node@0.0.0-baseline /tmp/fake-node
mise use --global node@0.0.0-baseline
check "a mise tool runs by name without activation" test "$(cd /tmp && node)" = fake-node
# Debian's /etc/profile resets PATH; the base image restores it for login shells.
check "a login shell keeps the shims on PATH" test "$(cd /tmp && bash -lc node)" = fake-node

reportResults
