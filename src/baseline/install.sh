#!/bin/sh
set -e

# dependsOn installs mise and the GitHub CLI, and containerEnv sets the
# environment. MISE_SHIMS_DIR moves mise's shims out of the user's home, so the
# static PATH entry finds them for any remote user. The remote user's
# `mise install` writes the shims there, so that user owns the directory.
mkdir -p "$MISE_SHIMS_DIR"
chown "$_REMOTE_USER" "$MISE_SHIMS_DIR"

# On Linux the Dev Container CLI can remap the remote user's UID after this
# script runs, and it re-owns only the home directory. onCreateCommand runs
# this helper as the remote user to take the shims directory back.
install -D -m 0755 "$(dirname "$0")/claim-mise-shims.sh" /usr/local/share/rubio-baseline/claim-mise-shims

# git refuses repositories owned by another user unless safe.directory lists
# them, and bind-mounted checkouts can report a foreign owner. System scope is
# protected configuration, so git honors it there, and safe.directory is
# multi-valued, so other entries in /etc/gitconfig add to this one.
if ! git config --system --get-all safe.directory | grep -qxF '/workspaces/*'; then
  git config --system --add safe.directory '/workspaces/*'
fi
