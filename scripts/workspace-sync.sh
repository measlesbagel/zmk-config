#!/usr/bin/env bash
set -euo pipefail

: "${DEVENV_ROOT:?Run this command from the Devenv environment}"

workspace="$DEVENV_ROOT/.west-workspace"
manifest_source="$DEVENV_ROOT/config/west.yml"
manifest_dir="$workspace/config"
manifest_copy="$manifest_dir/west.yml"
marker="$workspace/.manifest.sha256"

manifest_hash() {
    sha256sum "$manifest_source" | cut -d' ' -f1
}

workspace_current() {
    [[ -f "$workspace/.west/config" ]] || return 1
    [[ -d "$workspace/zmk/app" ]] || return 1
    [[ -f "$manifest_copy" ]] || return 1
    [[ -f "$marker" ]] || return 1
    [[ "$(<"$marker")" == "$(manifest_hash)" ]]
}

if [[ "${1:-}" == "--check" ]]; then
    workspace_current
    exit
fi

if workspace_current; then
    # The CMake package registry is outside the cached workspace, so refresh
    # it even when no network update is required (notably on fresh CI runners).
    (
        cd "$workspace"
        west zephyr-export
    )
    echo "West workspace is current"
    exit
fi

# West does not remove projects dropped from a manifest. Recreate an outdated
# workspace so dependency pruning also reduces local and CI cache size.
if [[ -f "$workspace/.west/config" ]]; then
    echo "Manifest changed; recreating the West workspace"
    rm -rf "$workspace"
fi

mkdir -p "$manifest_dir"
cp "$manifest_source" "$manifest_copy"

if [[ ! -f "$workspace/.west/config" ]]; then
    echo "Initializing West workspace in $workspace"
    (
        cd "$workspace"
        west init -l config
    )
fi

echo "Updating pinned West projects"
(
    cd "$workspace"
    west update --narrow --fetch-opt=--filter=tree:0
    west zephyr-export
)

manifest_hash >"$marker"
echo "West workspace is current"
