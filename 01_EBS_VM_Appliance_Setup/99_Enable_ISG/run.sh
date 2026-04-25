#!/bin/bash
# Phase 99 (OPTIONAL) — enable Integrated SOA Gateway.
# Only needed if you plan to use ISG / SOAP / REST service deployment.
# Runs as oracle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle

mkdir -p "$HOME/log"
cd "$HOME/log"

info "Running /u01/install/APPS/scripts/enableISG.sh"
/u01/install/APPS/scripts/enableISG.sh
ok "ISG enabled. See ~/log/L*.log for the report."
