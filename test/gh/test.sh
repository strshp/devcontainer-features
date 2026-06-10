#!/bin/bash

# デフォルトテスト: オプション無し・自動生成の devcontainer.json で実行する。
# remoteUser は既定で root。
#
# Feature が GH_CONFIG_DIR で gh をホストの bind マウントへ向けることを検証する。

set -e

source dev-container-features-test-lib

HOST_CONFIG=/var/gh-host-config

# マウント先が存在すること（Docker がマウント時に作成する）。
check "host config mount target exists" test -d "$HOST_CONFIG"

# gh 本体は github-cli の依存（dependsOn）で自動的にインストールされる。
check "gh is installed" bash -c 'command -v gh >/dev/null'

# gh は GH_CONFIG_DIR でホストの bind マウントへ向く（symlink は不要）。
check "GH_CONFIG_DIR -> host mount" bash -c '[ "$GH_CONFIG_DIR" = "/var/gh-host-config" ]'

# 機能確認: 設定ディレクトリへの書き込みがホストの bind マウントに届く。
check "write reaches host mount" bash -c '
    echo "test" > "$GH_CONFIG_DIR/.persist-test" &&
    test -f /var/gh-host-config/.persist-test
'

reportResults
