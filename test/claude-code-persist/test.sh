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

# Host-shared items must NEVER be dangling symlinks: when the host's ~/.claude
# lacks an item (no CLAUDE.md, commands/, agents/, ...), the path must stay
# valid (absent, a real per-repo entry, or a symlink whose target exists) so it
# can fall back to the per-repo store. If the host HAS the item, it is a symlink
# pointing at the host mount.
for item in .credentials.json settings.json settings.local.json keybindings.json CLAUDE.md skills commands agents output-styles rules workflows themes plugins; do
    if [ -e "$HOST/$item" ]; then
        check "$item -> host"           bash -c "[ \"\$(readlink /root/.claude/$item)\" = \"$HOST/$item\" ]"
    else
        check "$item not dangling"      bash -c "[ ! -L \"/root/.claude/$item\" ] || [ -e \"/root/.claude/$item\" ]"
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
# host. Guarded to an empty host mount (CI scratch dir) so we never mutate a
# developer's real ~/.claude on a local test run; we also clean up after.
if [ -z "$(ls -A "$HOST" 2>/dev/null)" ]; then
    WORKSPACE="$(dirname "$(dirname "$(readlink /root/.claude)")")"
    mkdir -p "$HOST/commands"
    printf '# memory\n' > "$HOST/CLAUDE.md"
    /usr/local/bin/claude-code-persist-init "$WORKSPACE"
    check "commands -> host once present"  bash -c "[ \"\$(readlink /root/.claude/commands)\" = \"$HOST/commands\" ]"
    check "CLAUDE.md -> host once present" bash -c "[ \"\$(readlink /root/.claude/CLAUDE.md)\" = \"$HOST/CLAUDE.md\" ]"
    check "CLAUDE.md readable via link"    test -f /root/.claude/CLAUDE.md
    rm -rf "$HOST/commands" "$HOST/CLAUDE.md"
fi

reportResults
