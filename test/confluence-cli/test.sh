#!/bin/bash

# デフォルトテスト: オプション無しの Feature。`confluence` コマンドがインストール
# され PATH に乗っていること、オプション未指定なら CONFLUENCE_* の env ファイルが
# 書き出されないことを検証する。

set -e

source dev-container-features-test-lib

# PyPI のパッケージ（kci-confluence-cli）が `confluence` コマンドを提供する。
check "confluence on PATH"          bash -c 'command -v confluence'
check "confluence --help works"     bash -c 'confluence --help >/dev/null 2>&1'

# オプション無し → env ファイルも無く、既存の環境を上書きしない。
check "no env file without options" bash -c '[ ! -e /etc/profile.d/confluence-cli.sh ]'

# inject_claude_docs は既定 true → Claude 向けガイドが注入される。
check "claude docs injected"        test -f /etc/claude-code/CLAUDE.md
check "claude docs has marker"      grep -q '^# BEGIN confluence-cli$' /etc/claude-code/CLAUDE.md
check "claude docs has usage"       grep -q 'confluence page get_body' /etc/claude-code/CLAUDE.md

reportResults
