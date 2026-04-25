#!/bin/bash
# Phase 06 — write sqlnet_ifile.ora with HOST_IP in invited_nodes,
# then bounce the CDB listener so changes take effect.
# Runs as oracle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle

info "Sourcing DB env: $DB_ENV"
# shellcheck disable=SC1090
source "$DB_ENV"
: "${TNS_ADMIN:?TNS_ADMIN not set after sourcing $DB_ENV}"

tns_dir="$TNS_ADMIN/$CONTEXT_NAME"
[[ -d "$tns_dir" ]] || die "Expected TNS dir not found: $tns_dir"

sqlnet_file="$tns_dir/sqlnet_ifile.ora"
backup_if_exists "$sqlnet_file"

info "Writing $sqlnet_file (invited_nodes: apps.example.com, $HOST_IP)"
cat > "$sqlnet_file" <<EOF
tcp.validnode_checking = YES
tcp.invited_nodes = (apps.example.com, $HOST_IP)
EOF

info "Restarting listener $CDB_NAME ..."
lsnrctl stop  "$CDB_NAME" || warn "lsnrctl stop returned non-zero (already stopped?)"
lsnrctl start "$CDB_NAME"

info "Verifying sqlnet_ifile.ora contents:"
echo "----- $sqlnet_file -----"
cat "$sqlnet_file"
echo "------------------------"

if grep -q "invited_nodes.*$HOST_IP" "$sqlnet_file"; then
    ok "HOST_IP ($HOST_IP) is present in tcp.invited_nodes."
else
    die "HOST_IP ($HOST_IP) NOT found in $sqlnet_file — check the file."
fi

ok "Listener bounced — your host ($HOST_IP) is now allowed to connect on 1521."
