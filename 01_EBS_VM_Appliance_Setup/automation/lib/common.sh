#!/bin/bash
# Shared helpers for the EBS post-import setup scripts.
# Source, don't execute.

# Resolve automation/ dir regardless of the caller's location.
EBS_AUTOMATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export EBS_AUTOMATION_DIR

# ------------------------------------------------------------
# Colored log helpers
# ------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\e[0m'; C_RED=$'\e[31m'; C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_BOLD=$'\e[1m'
else
    C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''
fi

_ts()  { date '+%Y-%m-%d %H:%M:%S'; }
info() { echo "${C_BLUE}[$(_ts)] [INFO]${C_RESET} $*"; }
ok()   { echo "${C_GREEN}[$(_ts)] [ OK ]${C_RESET} $*"; }
warn() { echo "${C_YELLOW}[$(_ts)] [WARN]${C_RESET} $*"; }
die()  { echo "${C_RED}[$(_ts)] [FAIL]${C_RESET} $*" >&2; exit 1; }

banner() {
    local bar
    bar=$(printf '=%.0s' {1..72})
    echo
    echo "${C_BOLD}${bar}${C_RESET}"
    echo "${C_BOLD}  $*${C_RESET}"
    echo "${C_BOLD}${bar}${C_RESET}"
}

# ------------------------------------------------------------
# Guards
# ------------------------------------------------------------
require_user() {
    local want=$1
    [[ "$(id -un)" == "$want" ]] \
        || die "This step must be run as '$want' (currently '$(id -un)')."
}

require_expect() {
    command -v expect >/dev/null 2>&1 \
        || die "'expect' not installed. Run: sudo yum install -y expect"
}

# ------------------------------------------------------------
# Config loader
# ------------------------------------------------------------
load_env() {
    local env_file="${1:-$EBS_AUTOMATION_DIR/ebs_setup.env}"
    [[ -r "$env_file" ]] \
        || die "Config not found: $env_file (copy ebs_setup.env.example first)."
    # shellcheck disable=SC1090
    set -a; source "$env_file"; set +a

    : "${NEW_PASSWORD:?NEW_PASSWORD not set}"
    : "${HOST_IP:?HOST_IP not set}"
    : "${NEW_WLS_PASSWORD:?NEW_WLS_PASSWORD not set}"
    : "${CURRENT_WLS_PASSWORD:=welcome1}"
    : "${CURRENT_EBS_SYSTEM_PASSWORD:=manager}"
    : "${SYS_PASSWORD:=$NEW_PASSWORD}"
    : "${SYSTEM_PASSWORD:=$NEW_PASSWORD}"
    : "${EBS_SYSTEM_PASSWORD:=$NEW_PASSWORD}"
    : "${APPS_USER:=apps}"
    : "${APPS_PASSWORD:=apps}"
    : "${CDB_NAME:=EBSCDB}"
    : "${PDB_NAME:=EBSDB}"
    : "${CONTEXT_NAME:=EBSDB_apps}"
    : "${APPS_ENV:=/u01/install/APPS/EBSapps.env}"
    : "${DB_ENV:=/u01/install/APPS/19.0.0/EBSCDB_apps.env}"
}

# ------------------------------------------------------------
# Utility
# ------------------------------------------------------------
backup_if_exists() {
    local f=$1
    [[ -f "$f" ]] && cp -p "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
}

log_dir() {
    local d="$HOME/log/ebs_setup_$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$d"
    echo "$d"
}

confirm() {
    local prompt="${1:-Proceed?} [y/N] "
    local ans
    read -r -p "$prompt" ans
    [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]
}
