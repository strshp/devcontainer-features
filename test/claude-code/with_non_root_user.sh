#!/bin/bash

# シナリオ: 非 root の remoteUser（octocat）。配線が（/root ではなく）当該ユーザーの
# ホームに作られ、そのユーザー所有になることを検証する。

set -e

source dev-container-features-test-lib

USER_HOME=/home/octocat
HOST=/var/claude-code-host

check "~/.claude -> workspace store" bash -c "[[ \"\$(readlink $USER_HOME/.claude)\" == */.devcontainer/claude-store ]]"
check "store dir exists"             test -d "$USER_HOME/.claude"
check "~/.claude.json -> host"       bash -c "[ \"\$(readlink $USER_HOME/.claude.json)\" = \"/var/claude-code-host-claude-json\" ]"
check ".credentials.json -> host"    bash -c "[ \"\$(readlink $USER_HOME/.claude/.credentials.json)\" = \"$HOST/.credentials.json\" ]"
check "~/.claude owned by octocat"   bash -c "[ \"\$(stat -c '%U' $USER_HOME/.claude)\" = \"octocat\" ]"

reportResults
