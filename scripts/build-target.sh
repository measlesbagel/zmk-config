#!/usr/bin/env bash
set -euo pipefail

: "${DEVENV_ROOT:?Run this command from the Devenv environment}"

target="${1:?usage: build-target.sh ARTIFACT_NAME}"
matrices=(
    "$DEVENV_ROOT/build.yaml"
    "$DEVENV_ROOT/build-reset.yaml"
)
workspace="$DEVENV_ROOT/.west-workspace"
build_dir="$DEVENV_ROOT/.build/$target"
firmware_dir="$DEVENV_ROOT/firmware"

if [[ ! -f "$workspace/.west/config" || ! -d "$workspace/zmk/app" ]]; then
    echo "West workspace is missing; run the firmware:workspace:sync task" >&2
    exit 1
fi

entry=""
for matrix in "${matrices[@]}"; do
    [[ -f "$matrix" ]] || continue
    candidate="$({
        # $target is a jq variable supplied by --arg, not a shell expansion.
        # shellcheck disable=SC2016
        yq -c --arg target "$target" \
            '.include[] | select(."artifact-name" == $target)' "$matrix"
    } || true)"

    if [[ -n "$candidate" ]]; then
        if [[ -n "$entry" || "$(printf '%s\n' "$candidate" | wc -l)" -ne 1 ]]; then
            echo "Multiple build manifests have artifact-name '$target'" >&2
            exit 1
        fi
        entry="$candidate"
    fi
done

if [[ -z "$entry" ]]; then
    echo "No build manifest entry has artifact-name '$target'" >&2
    exit 1
fi

board="$(jq -er '.board' <<<"$entry")"
shield="$(jq -r '.shield // empty' <<<"$entry")"
snippet="$(jq -r '.snippet // empty' <<<"$entry")"
cmake_string="$(jq -r '."cmake-args" // empty' <<<"$entry")"

west_args=(
    build
    -s "$workspace/zmk/app"
    -d "$build_dir"
    -b "$board"
)

if [[ -n "$snippet" ]]; then
    west_args+=(-S "$snippet")
fi

cmake_args=(
    "-DZMK_CONFIG=$DEVENV_ROOT/config"
    "-DZMK_EXTRA_MODULES=$DEVENV_ROOT"
)

if [[ -n "$shield" ]]; then
    cmake_args+=("-DSHIELD=$shield")
fi

if [[ -n "$cmake_string" ]]; then
    mapfile -d '' parsed_cmake_args < <(
        python - "$cmake_string" <<'PY'
import shlex
import sys

for value in shlex.split(sys.argv[1]):
    sys.stdout.buffer.write(value.encode() + b"\0")
PY
    )
    cmake_args+=("${parsed_cmake_args[@]}")
fi

echo "Building $target ($board${shield:+, $shield})"
(
    cd "$workspace"
    west "${west_args[@]}" -- "${cmake_args[@]}"
)

mkdir -p "$firmware_dir"

if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
    cp "$build_dir/zephyr/zmk.uf2" "$firmware_dir/$target.uf2"
elif [[ -f "$build_dir/zephyr/zmk.bin" ]]; then
    cp "$build_dir/zephyr/zmk.bin" "$firmware_dir/$target.bin"
else
    echo "Build succeeded but produced neither zmk.uf2 nor zmk.bin" >&2
    exit 1
fi

echo "Firmware written to $firmware_dir"
