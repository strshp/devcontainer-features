#!/bin/bash

# シナリオ: 非 root の remoteUser（octocat）。gh が GH_CONFIG_DIR で永続ストアへ
# 向き、そのディレクトリが当該ユーザーで書き込めることを検証する
# （マウント先が root 所有で作成された場合は gh-init が chown する）。

set -e

source dev-container-features-test-lib

check "running as octocat"        bash -c '[ "$(id -un)" = "octocat" ]'
check "GH_CONFIG_DIR -> store"    bash -c '[ "$GH_CONFIG_DIR" = "/var/gh-config" ]'
check "config dir writable by user" bash -c '
    echo "test" > "$GH_CONFIG_DIR/.persist-test-octocat" &&
    test -f /var/gh-config/.persist-test-octocat
'

reportResults
