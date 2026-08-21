#!/bin/bash
# Rebuilds (native arch only) and (re)launches Ruler.app
set -euo pipefail
cd "$(dirname "$0")"
./build.sh --fast
pkill -x Ruler 2>/dev/null || true
sleep 0.3
open build/Ruler.app
echo "Ruler is running — look for the ruler icon in the menu bar."
