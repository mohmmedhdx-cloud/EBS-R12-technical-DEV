#!/bin/bash
# Phase 04 — change passwords for DB product schemas via FNDCPASS ALLORACLE.
# APPS / APPLSYS / APPS_NE / APPLSYSPUB are NOT changed by this step.
# Also verifies + rotates the EBS_SYSTEM password (current default = 'manager').
# Runs as oracle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle
require_expect

mkdir -p "$HOME/log"
cd "$HOME/log"

info "Running /u01/install/APPS/scripts/changeDBpasswords.sh"
info "  new product schema pwd  : ${NEW_PASSWORD:0:1}***"
info "  current EBS_SYSTEM pwd  : $CURRENT_EBS_SYSTEM_PASSWORD (must match actual current value)"

expect <<EOF
set timeout 1800
log_user 1
spawn /u01/install/APPS/scripts/changeDBpasswords.sh
expect -re {Enter new password for base product schemas:}
send -- "$NEW_PASSWORD\r"
expect -re {Re-enter password for base product schemas:}
send -- "$NEW_PASSWORD\r"
expect -re {Enter password for EBS_SYSTEM:}
send -- "$CURRENT_EBS_SYSTEM_PASSWORD\r"
expect eof
catch wait result
exit [lindex \$result 3]
EOF

ok "Product schema + EBS_SYSTEM passwords rotated."
