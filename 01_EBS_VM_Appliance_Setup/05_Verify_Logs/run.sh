#!/bin/bash
# Phase 05 — verify password-change logs from phases 02-04.
# Runs as oracle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../automation/lib/common.sh
source "$SCRIPT_DIR/../automation/lib/common.sh"

load_env
require_user oracle

cd "$HOME/log"

shopt -s nullglob
logs=( L*.log )
[[ ${#logs[@]} -gt 0 ]] || die "No L*.log files found in $HOME/log — did phases 02-04 run?"

info "Successful password changes:"
grep -H 'changed successfully' "${logs[@]}" || warn "No success lines found."

echo
info "Scanning for errors / failures / invalid:"
if grep -E -i 'error|failed|invalid' "${logs[@]}"; then
    warn "Errors detected. Review the log lines above before continuing."
    exit 1
else
    ok "No errors found in any L*.log."
fi
