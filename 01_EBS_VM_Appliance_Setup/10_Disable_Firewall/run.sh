#!/bin/bash
# Phase 10 — stop and permanently disable firewalld so EBS ports
# (1521 DB, 7001 WLS, 8000 OHS, 9300 Fulfillment) are reachable
# from the Windows host. Runs as root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user root

info "Stopping firewalld ..."
systemctl stop firewalld    || warn "firewalld stop returned non-zero (already stopped?)"

info "Disabling firewalld at boot ..."
systemctl disable firewalld || warn "firewalld disable returned non-zero (already disabled?)"

systemctl status firewalld --no-pager || true
ok "firewalld stopped + disabled."
