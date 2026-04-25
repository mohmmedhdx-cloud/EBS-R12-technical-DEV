#!/bin/bash
# Phase 09 — change the WebLogic admin password.
# 3 sub-steps:
#   9.1  adstpall.sh -skipNM -skipAdmin       (stop mid-tier, leave NM+Admin)
#   9.2  txkUpdateEBSDomain.pl updateAdminPassword
#   9.3  adstrtal.sh                          (restart full tier with new pw)
# Runs as oracle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle
require_expect

info "Sourcing apps env: $APPS_ENV run"
# EBSapps.env trips set -e / set -u — disable them just around the source.
set +eu
# shellcheck disable=SC1090
source "$APPS_ENV" run
set -eu

# ----------------------------------------------------------------------
# 9.1 Stop the mid-tier (skip NodeManager + AdminServer so we can drive WLS)
# ----------------------------------------------------------------------
info "9.1/3 — adstpall.sh -skipNM -skipAdmin"
expect <<EOF
set timeout 1800
log_user 1
spawn adstpall.sh -skipNM -skipAdmin
expect -re {Enter the APPS username:}
send -- "$APPS_USER\r"
expect -re {Enter the APPS password:}
send -- "$APPS_PASSWORD\r"
expect -re {Enter the WebLogic Server password:}
send -- "$CURRENT_WLS_PASSWORD\r"
expect eof
catch wait result
exit [lindex \$result 3]
EOF
ok "Mid-tier stopped."

# ----------------------------------------------------------------------
# 9.2 Run the WLS-admin-password change.
# ----------------------------------------------------------------------
info "9.2/3 — txkUpdateEBSDomain.pl updateAdminPassword"
expect <<EOF
set timeout 1800
log_user 1
spawn perl $FND_TOP/patch/115/bin/txkUpdateEBSDomain.pl -action=updateAdminPassword
expect -re {Enter "Yes" to proceed or anything else to exit:}
send -- "YES\r"
expect -re {Enter the full path of Applications Context File.*:}
send -- "\r"
expect -re {Enter the WLS Admin Password:}
send -- "$CURRENT_WLS_PASSWORD\r"
expect -re {Enter the new WLS Admin Password:}
send -- "$NEW_WLS_PASSWORD\r"
expect -re {Enter the APPS user password:}
send -- "$APPS_PASSWORD\r"
expect eof
catch wait result
exit [lindex \$result 3]
EOF
ok "WebLogic admin password changed: $CURRENT_WLS_PASSWORD -> $NEW_WLS_PASSWORD"

# ----------------------------------------------------------------------
# 9.3 Bring the full app tier back up using the NEW WLS password.
# ----------------------------------------------------------------------
info "9.3/3 — adstrtal.sh (using NEW WLS password)"
expect <<EOF
set timeout 1800
log_user 1
spawn adstrtal.sh
expect -re {Enter the APPS username:}
send -- "$APPS_USER\r"
expect -re {Enter the APPS password:}
send -- "$APPS_PASSWORD\r"
expect -re {Enter the WebLogic Server password:}
send -- "$NEW_WLS_PASSWORD\r"
expect eof
catch wait result
exit [lindex \$result 3]
EOF
ok "Apps tier restarted with new WebLogic password."
