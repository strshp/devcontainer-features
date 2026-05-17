#!/bin/bash

# Scenario: a non-root remoteUser (octocat). Verifies the symlink lands
# in the user's home, not /root.

set -e

source dev-container-features-test-lib

USER_HOME=/home/octocat
HOST_CONFIG=/var/gh-host-config

check "~/.config/gh is a symlink"  test -L "$USER_HOME/.config/gh"
check "~/.config/gh -> host mount" bash -c "[ \"\$(readlink $USER_HOME/.config/gh)\" = \"$HOST_CONFIG\" ]"

reportResults
