#!/bin/bash

# シナリオ: オプション指定あり（既定の root ユーザー）。CLI がインストールされ、
# 3 つのオプションがログインシェルで CONFLUENCE_* として export されることを検証
# する。単一引用符を含むパスワードも含む（install.sh のクォート処理を試す）。

set -e

source dev-container-features-test-lib

check "confluence on PATH"     bash -c 'command -v confluence'

check "env file exists"        test -f /etc/profile.d/confluence-cli.sh
check "env file mode is 644"   bash -c '[ "$(stat -c %a /etc/profile.d/confluence-cli.sh)" = "644" ]'

# 値はログインシェルに export される。パスワードには単一引用符を含める。
export EXPECT_URL="https://confluence.example.com/confluence"
export EXPECT_USER="alice"
export EXPECT_PW="p@ss'w0rd"
check "CONFLUENCE_BASE_URL set"      bash -lc '[ "$CONFLUENCE_BASE_URL" = "$EXPECT_URL" ]'
check "CONFLUENCE_USER_NAME set"     bash -lc '[ "$CONFLUENCE_USER_NAME" = "$EXPECT_USER" ]'
check "CONFLUENCE_USER_PASSWORD set" bash -lc '[ "$CONFLUENCE_USER_PASSWORD" = "$EXPECT_PW" ]'

reportResults
