#!/bin/bash
cd "$(dirname "$0")/.."

if [ ! -d iGest.app ]; then
    echo "No iGest.app found. Run ./scripts/rebuild.sh first."
    exit 1
fi

open iGest.app
echo "✓ iGest started"
