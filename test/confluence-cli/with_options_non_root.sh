#!/bin/bash

# Scenario: options provided with a non-root remoteUser (octocat). Verifies the
# CLI is usable by the non-root user and the env file is owned by that user and
# exported into their login shells.

set -e

source dev-container-features-test-lib

check "running as octocat"        bash -c '[ "$(id -un)" = "octocat" ]'
check "confluence on PATH"        bash -c 'command -v confluence'
check "confluence --help works"   bash -c 'confluence --help >/dev/null 2>&1'

check "env file owned by octocat" bash -c '[ "$(stat -c %U /etc/profile.d/confluence-cli.sh)" = "octocat" ]'

export EXPECT_URL="https://confluence.example.com/confluence"
export EXPECT_PW="p@ss'w0rd"
check "CONFLUENCE_BASE_URL set"      bash -lc '[ "$CONFLUENCE_BASE_URL" = "$EXPECT_URL" ]'
check "CONFLUENCE_USER_PASSWORD set" bash -lc '[ "$CONFLUENCE_USER_PASSWORD" = "$EXPECT_PW" ]'

reportResults
