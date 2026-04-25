#!/bin/bash
# Phase 03 — enable the Vision demo users (~40 of them) and set their passwords.
# Runs as oracle. Long-running (several minutes).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle
require_expect

mkdir -p "$HOME/log"
cd "$HOME/log"

info "Running /u01/install/APPS/scripts/enableDEMOusers.sh — this can take a while."

expect <<EOF
set timeout 1800
log_user 1
spawn /u01/install/APPS/scripts/enableDEMOusers.sh
expect -re {Enter new password for DEMO users:}
send -- "$NEW_PASSWORD\r"
expect -re {Re-enter password for DEMO users:}
send -- "$NEW_PASSWORD\r"
expect eof
catch wait result
exit [lindex \$result 3]
EOF

ok "Vision demo users enabled with new password."
