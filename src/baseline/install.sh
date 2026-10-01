#!/bin/sh
set -e

# dependsOn installs mise and the GitHub CLI, and containerEnv sets the
# environment. MISE_SHIMS_DIR moves mise's shims out of the user's home, so the
# static PATH entry finds them for any remote user. The remote user's
# `mise install` writes the shims there, so that user owns the directory.
mkdir -p "$MISE_SHIMS_DIR"
chown "$_REMOTE_USER" "$MISE_SHIMS_DIR"
