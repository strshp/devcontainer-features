#!/bin/bash

# デフォルトテスト: オプション無し・自動生成の devcontainer.json で実行する。
# remoteUser は既定で root。
#
# Feature が GH_CONFIG_DIR で gh を専用の永続ストアへ向けることを検証する。

set -e

source dev-container-features-test-lib

CONFIG=/var/gh-config

# マウント先が存在すること（Docker がボリュームをマウントする）。
check "config mount target exists" test -d "$CONFIG"

# gh 本体は github-cli の依存（dependsOn）で自動的にインストールされる。
check "gh is installed" bash -c 'command -v gh >/dev/null'

# gh は GH_CONFIG_DIR で永続ストアへ向く。
check "GH_CONFIG_DIR -> store" bash -c '[ "$GH_CONFIG_DIR" = "/var/gh-config" ]'

# 機能確認: 設定ディレクトリへの書き込みが永続ストア（ボリューム）に届く。
check "write reaches store" bash -c '
    echo "test" > "$GH_CONFIG_DIR/.persist-test" &&
    test -f /var/gh-config/.persist-test
'

reportResults
