#!/bin/bash
# Pre-flight sanity check — run BEFORE ./00_run_all.sh
# Verifies environment is ready. Makes no changes.

set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

fail=0

check_cmd() {
    local label=$1 cmd=$2
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$label"
    else
        warn "$label — '$cmd' not found"
        fail=$((fail + 1))
    fi
}

check_file() {
    local label=$1 path=$2
    if [[ -r "$path" ]]; then
        ok "$label — $path"
    else
        warn "$label — missing or unreadable: $path"
        fail=$((fail + 1))
    fi
}

banner "EBS setup preflight"

# ----- 1. Right user? -----
info "1. Current user: $(id -un)  (expected: oracle)"
if [[ "$(id -un)" != "oracle" ]]; then
    warn "Not running as 'oracle' — 00_run_all.sh must be started as oracle."
    fail=$((fail + 1))
fi

# ----- 2. expect installed? -----
check_cmd "2. expect installed" expect

# ----- 3. env file present + parseable? -----
if [[ -r "$SCRIPT_DIR/ebs_setup.env" ]]; then
    ok "3. ebs_setup.env present"
    load_env
    info "   HOST_IP             : $HOST_IP"
    info "   CDB / PDB           : $CDB_NAME / $PDB_NAME"
    info "   NEW_PASSWORD        : ${NEW_PASSWORD:0:1}***"
    info "   APPS_USER/PASSWORD  : $APPS_USER / $APPS_PASSWORD"
    info "   CURRENT WLS pw      : $CURRENT_WLS_PASSWORD"
    info "   NEW WLS pw          : $NEW_WLS_PASSWORD"
    if [[ "$HOST_IP" == "192.168.1.100" ]]; then
        warn "   HOST_IP is still the template default — set it to your real Windows-host IP."
    fi
else
    warn "3. ebs_setup.env NOT FOUND — copy from ebs_setup.env.example and edit."
    fail=$((fail + 1))
fi

# ----- 4. passwordless sudo for root phases -----
info "4. Checking passwordless sudo for root-phase commands ..."
if sudo -n true 2>/dev/null; then
    ok "   sudo -n works (sudoers drop-in installed)"
else
    warn "   sudo -n blocked — run 'sudo bash setup_sudoers.sh' once as root,"
    warn "   or run the root phases (01, 08, 10) in a separate root SSH session."
fi

# ----- 5. EBS scripts exist -----
for s in enableSYSADMIN.sh enableDEMOusers.sh changeDBpasswords.sh enableISG.sh; do
    check_file "5. /u01/install/APPS/scripts/$s" "/u01/install/APPS/scripts/$s"
done

# ----- 6. Env-sourcing files exist -----
check_file "6. APPS env" "$APPS_ENV"
check_file "6. DB   env" "$DB_ENV"

# ----- 7. DB listener reachable at all (best-effort) -----
info "7. Checking DB listener on localhost:1521 ..."
if (echo > /dev/tcp/127.0.0.1/1521) 2>/dev/null; then
    ok "   port 1521 is open (DB listener running — OK, or a previous run)"
else
    info "   port 1521 not open yet — OK if DB hasn't been started (phase 01 will start it)"
fi

# ----- 8. Disk space in \$HOME -----
df_home=$(df -Pm "$HOME" | awk 'NR==2 {print $4}')
info "8. Free space in \$HOME: ${df_home} MB  (expect > 500 MB for logs)"
[[ "$df_home" -lt 500 ]] && { warn "Low free space"; fail=$((fail + 1)); }

# ----- Summary -----
echo
if [[ $fail -eq 0 ]]; then
    banner "Preflight PASSED — ready to run ./00_run_all.sh"
    exit 0
else
    banner "Preflight FAILED — $fail issue(s) above. Fix before running."
    exit 1
fi
