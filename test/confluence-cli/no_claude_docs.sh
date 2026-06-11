#!/bin/bash

# シナリオ: inject_claude_docs=false。confluence は入るが、Claude 向けガイドは
# 注入されない（/etc/claude-code/CLAUDE.md にマーカーが無い／ファイルが無い）。

set -e

source dev-container-features-test-lib

check "confluence on PATH"        bash -c 'command -v confluence'
check "no claude docs injected"   bash -c '[ ! -f /etc/claude-code/CLAUDE.md ] || ! grep -q "BEGIN confluence-cli" /etc/claude-code/CLAUDE.md'

reportResults
