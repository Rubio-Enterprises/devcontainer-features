#!/bin/sh
set -e

# Everything this feature provides is declarative in devcontainer-feature.json:
# dependsOn installs mise and the GitHub CLI, and containerEnv sets the
# environment. The spec still requires an install script.
echo "Rubio-Enterprises baseline: nothing to install beyond dependsOn."
