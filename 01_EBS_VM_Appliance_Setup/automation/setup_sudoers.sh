#!/bin/bash
# One-time setup: grant the 'oracle' user passwordless sudo for the specific
# commands needed by 00_run_all.sh. Run ONCE as root:
#     sudo bash setup_sudoers.sh
set -euo pipefail

[[ $(id -u) -eq 0 ]] || { echo "Must be run as root." >&2; exit 1; }

DROPIN=/etc/sudoers.d/oracle-ebs-setup

cat > "$DROPIN" <<'EOF'
# Allow the oracle user to start/stop the EBS services and manage firewalld
# without a password. Limited to the exact commands used by the automation.
Defaults:oracle !requiretty
oracle ALL=(root) NOPASSWD: /sbin/service ebscdb start, \
                           /usr/sbin/service ebscdb start, \
                           /sbin/service apps start, \
                           /usr/sbin/service apps start, \
                           /bin/systemctl stop firewalld, \
                           /usr/bin/systemctl stop firewalld, \
                           /bin/systemctl disable firewalld, \
                           /usr/bin/systemctl disable firewalld, \
                           /bin/systemctl status firewalld, \
                           /usr/bin/systemctl status firewalld
EOF

chmod 0440 "$DROPIN"

if visudo -c -q; then
    echo "[ OK ] Installed $DROPIN"
else
    echo "[FAIL] sudoers syntax check failed — removing."
    rm -f "$DROPIN"
    exit 1
fi
