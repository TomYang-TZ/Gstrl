#!/bin/bash
pkill -f iGest 2>/dev/null && echo "✓ iGest stopped" || echo "iGest not running"
