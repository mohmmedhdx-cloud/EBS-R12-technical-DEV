#!/bin/bash
# Phase 02 — enable the SYSADMIN EBS Applications user and set its password.
# Runs as oracle. Feeds the new password to enableSYSADMIN.sh via expect.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle
require_expect

mkdir -p "$HOME/log"
cd "$HOME/log"

info "Running /u01/install/APPS/scripts/enableSYSADMIN.sh (new pwd: ${NEW_PASSWORD:0:1}***)"

expect <<EOF
set timeout 600
log_user 1
spawn /u01/install/APPS/scripts/enableSYSADMIN.sh
expect -re {Enter new password for SYSADMIN:}
send -- "$NEW_PASSWORD\r"
expect -re {Re-enter password for SYSADMIN:}
send -- "$NEW_PASSWORD\r"
expect eof
catch wait result
exit [lindex \$result 3]
EOF

ok "SYSADMIN password set."
