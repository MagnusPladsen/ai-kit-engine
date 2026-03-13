#!/bin/bash
# Go Kit — Installer
# Thin wrapper that delegates to the AI Kit Engine submodule.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$SCRIPT_DIR/engine/install.sh"

# Auto-init submodule if engine is missing
if [ ! -f "$ENGINE" ]; then
    echo "Fetching installer engine..."
    git -C "$SCRIPT_DIR" submodule update --init --recursive 2>/dev/null
    if [ ! -f "$ENGINE" ]; then
        echo "Error: Could not fetch engine. Run: git submodule update --init"
        exit 1
    fi
fi

# Copy engine to temp file, then update submodule in background.
_ENGINE_TMP="$(mktemp)"
cp "$ENGINE" "$_ENGINE_TMP"
trap 'rm -f "$_ENGINE_TMP"' EXIT

# Background update — fetched for NEXT run, not this one
git -C "$SCRIPT_DIR" submodule update --remote engine 2>/dev/null &

exec bash "$_ENGINE_TMP" --kit-dir "$SCRIPT_DIR" "$@"
