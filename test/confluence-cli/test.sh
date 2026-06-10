#!/bin/bash

# Default test: the feature with no options. The `confluence` command must be
# installed and on PATH, and with no options given no CONFLUENCE_* env file is
# written.

set -e

source dev-container-features-test-lib

# The CLI from PyPI (kci-confluence-cli) provides the `confluence` command.
check "confluence on PATH"          bash -c 'command -v confluence'
check "confluence --help works"     bash -c 'confluence --help >/dev/null 2>&1'

# No options -> no env file, so nothing overrides the ambient environment.
check "no env file without options" bash -c '[ ! -e /etc/profile.d/confluence-cli.sh ]'

reportResults
