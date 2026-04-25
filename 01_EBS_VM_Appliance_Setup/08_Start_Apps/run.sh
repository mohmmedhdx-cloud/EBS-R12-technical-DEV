#!/bin/bash
# Phase 08 — start the EBS apps tier services (forms, OPMN, OHS,
# Node Manager, AdminServer, oacore/oafm/forms managed servers, ICM).
# Runs as root. Takes 5-15 minutes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user root

info "Starting EBS apps tier (this takes several minutes) ..."
service apps start
ok "Apps tier services started."
