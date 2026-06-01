#!/bin/bash

# Default test: runs against an auto-generated devcontainer.json with the
# gh-persist feature and no options. remoteUser defaults to root.
#
# Verifies that the feature points gh at the host bind mount via GH_CONFIG_DIR.

set -e

source dev-container-features-test-lib

HOST_CONFIG=/var/gh-host-config

# Mount target must exist (Docker creates it on mount).
check "host config mount target exists" test -d "$HOST_CONFIG"

# gh itself is installed automatically via the github-cli dependency (dependsOn).
check "gh is installed" bash -c 'command -v gh >/dev/null'

# gh is pointed at the host bind mount via GH_CONFIG_DIR (no symlink needed).
check "GH_CONFIG_DIR -> host mount" bash -c '[ "$GH_CONFIG_DIR" = "/var/gh-host-config" ]'

# Functional check: writing into the config dir lands on the host bind mount.
check "write reaches host mount" bash -c '
    echo "test" > "$GH_CONFIG_DIR/.persist-test" &&
    test -f /var/gh-host-config/.persist-test
'

reportResults
