#!/usr/bin/env bash
set -euo pipefail

: "${DEVENV_ROOT:?Run this command from the prepared Devenv environment}"

# The prepare job enters this command once to materialize a reusable Devenv
# shell script. Matrix jobs provide TARGET when they execute that cached shell.
target="${TARGET:-}"
if [[ -z "$target" ]]; then
    exit 0
fi

bash "$DEVENV_ROOT/scripts/workspace-sync.sh"
exec bash "$DEVENV_ROOT/scripts/build-target.sh" "$target"
