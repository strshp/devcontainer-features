#!/bin/bash

# シナリオ: 非 root の remoteUser（octocat）でオプション指定あり。非 root ユーザー
# でも CLI が使え、env ファイルが全ユーザー読み取り可で、当該ユーザーのログイン
# シェルに export されることを検証する。

set -e

source dev-container-features-test-lib

check "running as octocat"        bash -c '[ "$(id -un)" = "octocat" ]'
check "confluence on PATH"        bash -c 'command -v confluence'
check "confluence --help works"   bash -c 'confluence --help >/dev/null 2>&1'

check "env file is world-readable" bash -c '[ "$(stat -c %a /etc/profile.d/confluence-cli.sh)" = "644" ]'

export EXPECT_URL="https://confluence.example.com/confluence"
export EXPECT_PW="p@ss'w0rd"
check "CONFLUENCE_BASE_URL set"      bash -lc '[ "$CONFLUENCE_BASE_URL" = "$EXPECT_URL" ]'
check "CONFLUENCE_USER_PASSWORD set" bash -lc '[ "$CONFLUENCE_USER_PASSWORD" = "$EXPECT_PW" ]'

reportResults
