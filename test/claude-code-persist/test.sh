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

# For each shared item: if the host HAS it, it is a symlink to the host mount.
# If the host lacks it, the feature does nothing — no symlink is created (so
# nothing is dangling) and nothing is created on the host.
for item in .credentials.json settings.json settings.local.json keybindings.json CLAUDE.md skills commands agents output-styles rules workflows themes plugins; do
    if [ -e "$HOST/$item" ]; then
        check "$item -> host"           bash -c "[ \"\$(readlink /root/.claude/$item)\" = \"$HOST/$item\" ]"
    else
        check "$item has no symlink"    bash -c "[ ! -L \"/root/.claude/$item\" ]"
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

# Positive path: once the host gains an item, re-running init links it from the
# host. Guarded on the file being absent so we never clobber a developer's real
# ~/.claude on a local run; we remove only what we create.
if [ ! -e "$HOST/CLAUDE.md" ]; then
    WORKSPACE="$(dirname "$(dirname "$(readlink /root/.claude)")")"
    printf '# memory\n' > "$HOST/CLAUDE.md"
    /usr/local/bin/claude-code-persist-init "$WORKSPACE"
    check "CLAUDE.md -> host once present" bash -c "[ \"\$(readlink /root/.claude/CLAUDE.md)\" = \"$HOST/CLAUDE.md\" ]"
    check "CLAUDE.md readable via link"    test -f /root/.claude/CLAUDE.md
    rm -f "$HOST/CLAUDE.md"
fi

reportResults
