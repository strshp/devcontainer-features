#!/bin/bash

# Default test: runs against an auto-generated devcontainer.json with the
# claude-code-persist feature and no options. remoteUser defaults to root.
#
# Verifies the wiring: ~/.claude is the per-repo store (inside the workspace's
# .devcontainer/), and ~/.claude.json plus the host-shared config/credential
# items point at the host mount.

set -e

source dev-container-features-test-lib

HOST=/var/claude-code-host

# Host mount target must exist (host's ~/.claude is bind-mounted here).
check "host mount target exists"        test -d "$HOST"

# ~/.claude is the per-repo store, created inside the workspace's .devcontainer.
check "~/.claude is a symlink"          test -L /root/.claude
check "~/.claude -> workspace store"    bash -c '[[ "$(readlink /root/.claude)" == */.devcontainer/claude-store ]]'
check "store dir exists"                test -d /root/.claude

# ~/.claude.json is shared from the host (it lives at the home root).
check "~/.claude.json -> host"          bash -c '[ "$(readlink /root/.claude.json)" = "/var/claude-code-host-claude-json" ]'

# Host-shared items: symlinks inside the store pointing at the host mount. The
# link is created unconditionally (it may be dangling when the host lacks the
# item — accepted by design), and the feature never creates it on the host.
for item in .credentials.json settings.json settings.local.json keybindings.json CLAUDE.md skills commands agents output-styles rules workflows themes plugins; do
    check "$item -> host"               bash -c "[ \"\$(readlink /root/.claude/$item)\" = \"$HOST/$item\" ]"
    if [ ! -e "$HOST/$item" ]; then
        check "$item not created on host" bash -c "[ ! -e \"$HOST/$item\" ]"
    fi
done

# Runtime state defaults to the per-repo store. (Safe: writes only into the
# store under the workspace, never the host's real ~/.claude.)
check "runtime write stays in store" bash -c '
    mkdir -p /root/.claude/projects &&
    echo hello > /root/.claude/projects/.persist-test &&
    test -f /root/.claude/projects/.persist-test
'

reportResults
