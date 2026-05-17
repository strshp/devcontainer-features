#!/bin/bash

# Scenario: a non-root remoteUser (octocat). Verifies the symlinks land
# in the user's home, not /root.

set -e

source dev-container-features-test-lib

USER_HOME=/home/octocat
GLOBAL=/var/claude-code-global
PROJECTS=/var/claude-code-projects

check "~/.claude is a symlink"      test -L "$USER_HOME/.claude"
check "~/.claude.json is a symlink" test -L "$USER_HOME/.claude.json"
check "~/.claude -> global"         bash -c "[ \"\$(readlink $USER_HOME/.claude)\" = \"$GLOBAL\" ]"
check "~/.claude.json -> global"    bash -c "[ \"\$(readlink $USER_HOME/.claude.json)\" = \"$GLOBAL/.claude.json\" ]"

# Sanity-check one of the nested project-scoped symlinks.
check "projects symlink"            test -L "$GLOBAL/projects"
check "projects -> project mount"   bash -c "[ \"\$(readlink $GLOBAL/projects)\" = \"$PROJECTS/projects\" ]"

reportResults
