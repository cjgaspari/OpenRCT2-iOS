#!/usr/bin/env bash
set -euo pipefail

# One-click physical iPhone Duo build, install, and launch. The --duo selector
# intentionally fails instead of falling back to another connected iPhone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/play-ios-device.sh" --duo "$@"
