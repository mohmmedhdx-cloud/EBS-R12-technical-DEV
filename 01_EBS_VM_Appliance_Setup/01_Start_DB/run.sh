#!/bin/bash
# Phase 01 — start the container database. Runs as root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user root

svc=$(echo "$CDB_NAME" | tr '[:upper:]' '[:lower:]')

info "Starting container DB via: service $svc start"
service "$svc" start
ok "Container DB '$CDB_NAME' started (listener on 1521)."
