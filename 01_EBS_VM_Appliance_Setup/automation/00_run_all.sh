#!/bin/bash
# Master driver — runs every phase's run.sh in order.
# Lives in automation/; phases live in ../NN_*/run.sh as siblings of automation/.
# Run as the 'oracle' user. Uses sudo for the 3 root-level phases
# (see setup_sudoers.sh for the one-time sudoers drop-in).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

load_env
require_user oracle
require_expect

LOG_BASE="$(log_dir)"

banner "EBS R12.2 Vision VM — automated post-import setup"
info "Project root  : $PROJECT_ROOT"
info "Log dir       : $LOG_BASE"
info "CDB / PDB     : $CDB_NAME / $PDB_NAME"
info "Context       : $CONTEXT_NAME"
info "Your host IP  : $HOST_IP"
info "WLS change    : $CURRENT_WLS_PASSWORD -> $NEW_WLS_PASSWORD"
info "EBS pw        : $NEW_PASSWORD    APPS pw: $APPS_PASSWORD"
echo

if ! confirm "Run all 10 phases now?"; then
    warn "Aborted by user."
    exit 0
fi

run_phase() {
    local num=$1 name=$2 mode=$3 folder=$4
    banner "Phase $num/10 — $name"
    local logfile="$LOG_BASE/${num}_${name// /_}.log"
    local cmd=( bash "$PROJECT_ROOT/$folder/run.sh" )
    if [[ "$mode" == "sudo" ]]; then
        sudo -n "${cmd[@]}" 2>&1 | tee "$logfile"
    else
        "${cmd[@]}" 2>&1 | tee "$logfile"
    fi
    ok "Phase $num done. Log: $logfile"
}

run_phase 01 "start container DB"          sudo   01_Start_DB
run_phase 02 "enable SYSADMIN"             user   02_Enable_SYSADMIN
run_phase 03 "enable demo users"           user   03_Enable_Demo_Users
run_phase 04 "change DB product pwds"      user   04_Change_DB_Passwords
run_phase 05 "verify logs"                 user   05_Verify_Logs
run_phase 06 "configure sqlnet"            user   06_Configure_Sqlnet
run_phase 07 "alter SYS SYSTEM EBS_SYSTEM" user   07_Alter_DB_Users
run_phase 08 "start apps tier"             sudo   08_Start_Apps
run_phase 09 "update WebLogic password"    user   09_Update_WebLogic
run_phase 10 "disable firewalld"           sudo   10_Disable_Firewall

banner "All phases complete"
ok  "Log directory : $LOG_BASE"
echo
info "Open EBS      : http://apps.example.com:8000/OA_HTML/AppsLogin"
info "EBS login     : SYSADMIN / $NEW_PASSWORD   (or OPERATIONS / $NEW_PASSWORD)"
info "APPS schema   : $APPS_USER / $APPS_PASSWORD   (not changed by this setup)"
info "WebLogic      : weblogic / $NEW_WLS_PASSWORD"
