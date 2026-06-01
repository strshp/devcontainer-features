#!/bin/bash

# Scenario: a non-root remoteUser (octocat). Verifies gh is pointed at the host
# bind mount via GH_CONFIG_DIR and that the directory is writable by that user
# (gh-persist-init chowns it when Docker created the mount target as root).

set -e

source dev-container-features-test-lib

check "running as octocat"           bash -c '[ "$(id -un)" = "octocat" ]'
check "GH_CONFIG_DIR -> host mount"  bash -c '[ "$GH_CONFIG_DIR" = "/var/gh-host-config" ]'
check "config dir writable by user"  bash -c '
    echo "test" > "$GH_CONFIG_DIR/.persist-test-octocat" &&
    test -f /var/gh-host-config/.persist-test-octocat
'

reportResults
