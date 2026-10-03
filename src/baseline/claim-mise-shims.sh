#!/bin/sh
# Runs as the remote user from the feature's onCreateCommand, before any
# repository lifecycle command can run `mise install`. When a Linux host's UID
# remap left the shims directory owned by the old UID, take it back with sudo;
# otherwise do nothing. sudo -n fails instead of prompting, so a container
# without passwordless sudo stops here with an error rather than later in
# `mise install`.
set -e
dir="${MISE_SHIMS_DIR:?MISE_SHIMS_DIR is not set}"
[ -w "$dir" ] && exit 0
sudo -n chown "$(id -u):$(id -g)" "$dir"
