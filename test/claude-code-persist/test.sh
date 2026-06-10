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

# Shared config FILES are always linked to the host: when the host lacks one it
# is created with its documented initial state, so the link is never dangling
# and the file is shared with the host.
for item in settings.json settings.local.json keybindings.json CLAUDE.md; do
    check "$item -> host"               bash -c "[ \"\$(readlink /root/.claude/$item)\" = \"$HOST/$item\" ]"
    check "$item is a regular file"     test -f "/root/.claude/$item"
done

# Fabricated JSON config has valid, parseable content. Validate with whatever
# JSON parser the image happens to have (node ships with the claude-code dep);
# skip the check if none is available rather than fail spuriously.
if command -v node >/dev/null 2>&1; then
    JSON_PARSE='node -e "JSON.parse(require(\"fs\").readFileSync(process.argv[1],\"utf8\"))"'
elif command -v python3 >/dev/null 2>&1; then
    JSON_PARSE='python3 -c "import json,sys; json.load(open(sys.argv[1]))"'
else
    JSON_PARSE=''
fi
if [ -n "$JSON_PARSE" ]; then
    for item in settings.json settings.local.json keybindings.json; do
        check "$item is valid JSON" sh -c "$JSON_PARSE /root/.claude/$item"
    done
fi

# .credentials.json is auth material: never fabricated. Linked only when the
# host already has it; otherwise the path must not be a dangling symlink.
if [ -e "$HOST/.credentials.json" ]; then
    check ".credentials.json -> host" bash -c "[ \"\$(readlink /root/.claude/.credentials.json)\" = \"$HOST/.credentials.json\" ]"
else
    check ".credentials.json not dangling" bash -c "[ ! -L \"/root/.claude/.credentials.json\" ] || [ -e \"/root/.claude/.credentials.json\" ]"
fi

# Runtime state defaults to the per-repo store. (Safe: writes only into the
# store under the workspace, never the host's real ~/.claude.)
check "runtime write stays in store" bash -c '
    mkdir -p /root/.claude/projects &&
    echo hello > /root/.claude/projects/.persist-test &&
    test -f /root/.claude/projects/.persist-test
'

reportResults
