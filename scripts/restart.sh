#!/bin/bash
cd "$(dirname "$0")"
./scripts/stop.sh
sleep 0.5
./scripts/rebuild.sh
./scripts/start.sh
