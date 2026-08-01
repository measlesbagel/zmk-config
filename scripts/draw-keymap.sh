#!/usr/bin/env bash
set -euo pipefail

: "${DEVENV_ROOT:?Run this command from the Devenv environment}"

drawer_config="$DEVENV_ROOT/keymap_drawer.config.yaml"
keymap="$DEVENV_ROOT/config/bridges_v2.keymap"
yaml="$DEVENV_ROOT/keymap-drawer/bridges.yaml"
svg="$DEVENV_ROOT/keymap-drawer/bridges.svg"
layout="$DEVENV_ROOT/.west-workspace/modules/bridges-v2-zmk-firmware/boards/measlesbagel/bridges_v2/layout_54.dtsi"

if [[ ! -f "$layout" ]]; then
    echo "Bridges physical layout is missing; run the firmware:workspace:sync task" >&2
    exit 1
fi

mkdir -p "$(dirname "$yaml")"

tmp_yaml="$(mktemp --tmpdir="$(dirname "$yaml")" bridges.tmp.XXXXXX.yaml)"
tmp_svg="$(mktemp --tmpdir="$(dirname "$svg")" bridges.tmp.XXXXXX.svg)"
trap 'rm -f "$tmp_yaml" "$tmp_svg"' EXIT

keymap -c "$drawer_config" parse -z "$keymap" >"$tmp_yaml"
keymap -c "$drawer_config" draw \
    --dts-layout "$layout" \
    --layout-name measlesbagel_bridges_54_layout \
    "$tmp_yaml" >"$tmp_svg"

if [[ "${1:-}" == "--check" ]]; then
    diff -u "$yaml" "$tmp_yaml"
    diff -u "$svg" "$tmp_svg"
    echo "Keymap drawing is current"
else
    mv "$tmp_yaml" "$yaml"
    mv "$tmp_svg" "$svg"
    echo "Updated $yaml and $svg"
fi
