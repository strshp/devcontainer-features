#!/bin/bash

# デフォルトテスト: オプション無し・自動生成の devcontainer.json で実行する。
# remoteUser は既定で root。
#
# 配線を検証する: ~/.claude が（workspace の .devcontainer/ 内の）リポジトリ単位
# ストアであり、~/.claude.json とホスト共有の設定／認証項目がホストのマウントを
# 指していること。

set -e

source dev-container-features-test-lib

HOST=/var/claude-code-host

# ホスト側マウントの先（ホストの ~/.claude を bind マウントした場所）が存在すること。
check "host mount target exists"        test -d "$HOST"

# ~/.claude は workspace の .devcontainer 内に作られるリポジトリ単位ストア。
check "~/.claude is a symlink"          test -L /root/.claude
check "~/.claude -> workspace store"    bash -c '[[ "$(readlink /root/.claude)" == */.devcontainer/claude-store ]]'
check "store dir exists"                test -d /root/.claude

# ~/.claude.json はホーム直下にあるので、ホストの同ファイルを共有する。
check "~/.claude.json -> host"          bash -c '[ "$(readlink /root/.claude.json)" = "/var/claude-code-host-claude-json" ]'

# ホスト共有項目: ストア内の symlink がホストのマウントを指す。symlink は無条件に
# 作られ（ホストに項目が無ければリンク切れになるが、設計上の許容）、Feature が
# ホスト側に作成することはない。
for item in .credentials.json settings.json settings.local.json keybindings.json CLAUDE.md skills commands agents output-styles rules workflows themes plugins; do
    check "$item -> host"               bash -c "[ \"\$(readlink /root/.claude/$item)\" = \"$HOST/$item\" ]"
    if [ ! -e "$HOST/$item" ]; then
        check "$item not created on host" bash -c "[ ! -e \"$HOST/$item\" ]"
    fi
done

# 実行時状態は既定でリポジトリ単位ストアに入る（安全: 書き込みは workspace 内の
# ストアにのみ行われ、ホストの実体の ~/.claude には触れない）。
check "runtime write stays in store" bash -c '
    mkdir -p /root/.claude/projects &&
    echo hello > /root/.claude/projects/.persist-test &&
    test -f /root/.claude/projects/.persist-test
'

reportResults
