#!/bin/bash

# Scenario: a non-root remoteUser (octocat). Verifies the wiring lands in the
# user's home (not /root) and is owned by that user.

set -e

source dev-container-features-test-lib

USER_HOME=/home/octocat
HOST=/var/claude-code-host

check "~/.claude -> workspace store" bash -c "[[ \"\$(readlink $USER_HOME/.claude)\" == */.devcontainer/claude-store ]]"
check "store dir exists"             test -d "$USER_HOME/.claude"
check "~/.claude.json -> host"       bash -c "[ \"\$(readlink $USER_HOME/.claude.json)\" = \"/var/claude-code-host-claude-json\" ]"
# .credentials.json is shared from the host only when the host actually has it;
# otherwise the path must not be a dangling symlink (falls back to the store).
if [ -e "$HOST/.credentials.json" ]; then
    check ".credentials.json -> host" bash -c "[ \"\$(readlink $USER_HOME/.claude/.credentials.json)\" = \"$HOST/.credentials.json\" ]"
else
    check ".credentials.json not dangling" bash -c "[ ! -L \"$USER_HOME/.claude/.credentials.json\" ] || [ -e \"$USER_HOME/.claude/.credentials.json\" ]"
fi
check "~/.claude owned by octocat"   bash -c "[ \"\$(stat -c '%U' $USER_HOME/.claude)\" = \"octocat\" ]"

reportResults
