#!/bin/bash
# Phase 07 — set DB-tier user passwords:
#   CDB:  SYS, SYSTEM
#   PDB:  EBS_SYSTEM
# Runs as oracle (uses '/ as sysdba').
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle

info "Sourcing DB env: $DB_ENV"
# shellcheck disable=SC1090
source "$DB_ENV"

info "Altering SYS / SYSTEM (CDB) and EBS_SYSTEM (PDB=$PDB_NAME)."

sqlplus -S / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET FEEDBACK ON
ALTER USER SYSTEM IDENTIFIED BY "$SYSTEM_PASSWORD";
ALTER USER SYS    IDENTIFIED BY "$SYS_PASSWORD";
ALTER SESSION SET CONTAINER = $PDB_NAME;
ALTER USER EBS_SYSTEM IDENTIFIED BY "$EBS_SYSTEM_PASSWORD";
EXIT
SQL

ok "DB-tier user passwords updated."
