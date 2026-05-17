#!/bin/bash

# Default test: runs against an auto-generated devcontainer.json with the
# claude-code-persist feature and no options. remoteUser defaults to root.
#
# This verifies that install.sh wired up the symlinks correctly inside the
# container. End-to-end data persistence across rebuilds is exercised by
# the devcontainer-cli test harness itself when it rebuilds the container.

set -e

source dev-container-features-test-lib

GLOBAL=/var/claude-code-global
PROJECTS=/var/claude-code-projects
SKILLS=/var/claude-code-host-skills

# Mount targets must exist (Docker creates them on mount).
check "global mount target exists"   test -d "$GLOBAL"
check "projects mount target exists" test -d "$PROJECTS"
check "skills mount target exists"   test -d "$SKILLS"

# ~/.claude and ~/.claude.json should be symlinks into the global volume.
check "~/.claude is a symlink"       test -L /root/.claude
check "~/.claude.json is a symlink"  test -L /root/.claude.json
check "~/.claude -> global"          bash -c '[ "$(readlink /root/.claude)" = "/var/claude-code-global" ]'
check "~/.claude.json -> global"     bash -c '[ "$(readlink /root/.claude.json)" = "/var/claude-code-global/.claude.json" ]'

# Each project-scoped entry inside the global volume should be a symlink
# pointing into the project bind mount.
for name in projects todos shell-snapshots sessions session-env tasks plans file-history paste-cache history.jsonl; do
    check "$name is a symlink"       test -L "$GLOBAL/$name"
    check "$name -> project mount"   bash -c "[ \"\$(readlink $GLOBAL/$name)\" = \"$PROJECTS/$name\" ]"
done

# skills should be a symlink to the host-skills bind mount.
check "skills is a symlink"          test -L "$GLOBAL/skills"
check "skills -> host mount"         bash -c '[ "$(readlink /var/claude-code-global/skills)" = "/var/claude-code-host-skills" ]'

# Functional check: writing through ~/.claude/projects lands on the project bind mount.
check "write reaches project mount" bash -c '
    echo hello > /root/.claude/projects/.persist-test &&
    test -f /var/claude-code-projects/projects/.persist-test &&
    grep -q hello /var/claude-code-projects/projects/.persist-test
'

reportResults
