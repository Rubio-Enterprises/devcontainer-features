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

reportResults
