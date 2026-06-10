#!/bin/bash

# Scenario: options provided (default root user). Verifies the CLI is installed
# and the three options are exported as CONFLUENCE_* in login shells, including
# a password that contains a single quote (exercises the quoting in install.sh).

set -e

source dev-container-features-test-lib

check "confluence on PATH"     bash -c 'command -v confluence'

check "env file exists"        test -f /etc/profile.d/confluence-cli.sh
check "env file mode is 600"   bash -c '[ "$(stat -c %a /etc/profile.d/confluence-cli.sh)" = "600" ]'

# Values are exported into login shells. The password contains a single quote.
export EXPECT_URL="https://confluence.example.com/confluence"
export EXPECT_USER="alice"
export EXPECT_PW="p@ss'w0rd"
check "CONFLUENCE_BASE_URL set"      bash -lc '[ "$CONFLUENCE_BASE_URL" = "$EXPECT_URL" ]'
check "CONFLUENCE_USER_NAME set"     bash -lc '[ "$CONFLUENCE_USER_NAME" = "$EXPECT_USER" ]'
check "CONFLUENCE_USER_PASSWORD set" bash -lc '[ "$CONFLUENCE_USER_PASSWORD" = "$EXPECT_PW" ]'

reportResults
