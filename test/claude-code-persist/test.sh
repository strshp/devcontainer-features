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

# Shared DIRS are always linked to the host: the host dir is created empty when
# absent, so the link is never dangling and the dir is truly shared.
for item in skills commands agents output-styles rules workflows themes plugins; do
    check "$item -> host"               bash -c "[ \"\$(readlink /root/.claude/$item)\" = \"$HOST/$item\" ]"
    check "$item host dir exists"       test -d "$HOST/$item"
    check "$item link not dangling"     test -d "/root/.claude/$item"
done

# Shared FILES must never be dangling: when the host lacks the file (no
# CLAUDE.md, keybindings.json, ...) the path stays valid (absent, a real
# per-repo entry, or a symlink whose target exists) and falls back to the
# per-repo store. If the host HAS the file, it is a symlink to the host mount.
for item in .credentials.json settings.json settings.local.json keybindings.json CLAUDE.md; do
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

# Positive path for FILES: once the host gains a shared file, re-running init
# links it from the host. Guarded on the file being absent so we never clobber a
# developer's real ~/.claude/CLAUDE.md on a local run; we remove only what we
# create. (Shared dirs are covered by the always-linked checks above.)
if [ ! -e "$HOST/CLAUDE.md" ]; then
    WORKSPACE="$(dirname "$(dirname "$(readlink /root/.claude)")")"
    printf '# memory\n' > "$HOST/CLAUDE.md"
    /usr/local/bin/claude-code-persist-init "$WORKSPACE"
    check "CLAUDE.md -> host once present" bash -c "[ \"\$(readlink /root/.claude/CLAUDE.md)\" = \"$HOST/CLAUDE.md\" ]"
    check "CLAUDE.md readable via link"    test -f /root/.claude/CLAUDE.md
    rm -f "$HOST/CLAUDE.md"
fi

reportResults
