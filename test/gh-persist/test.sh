#!/bin/bash

# Default test: runs against an auto-generated devcontainer.json with the
# gh-persist feature and no options. remoteUser defaults to root.
#
# Verifies that install.sh wired up the symlink correctly inside the container.

set -e

source dev-container-features-test-lib

HOST_CONFIG=/var/gh-host-config

# Mount target must exist (Docker creates it on mount).
check "host config mount target exists" test -d "$HOST_CONFIG"

# ~/.config/gh should be a symlink pointing to the host bind mount.
check "~/.config/gh is a symlink"     test -L /root/.config/gh
check "~/.config/gh -> host mount"    bash -c '[ "$(readlink /root/.config/gh)" = "/var/gh-host-config" ]'

# Functional check: writing through ~/.config/gh lands on the host bind mount.
check "write reaches host mount" bash -c '
    mkdir -p /root/.config/gh &&
    echo "test" > /root/.config/gh/.persist-test &&
    test -f /var/gh-host-config/.persist-test
'

reportResults
