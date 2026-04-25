# Phase 06 — Configure SQL*Net Invited Nodes

**Run as:** `oracle` &nbsp;&nbsp; **Time:** ~30 seconds

## What it does
Writes `sqlnet_ifile.ora` with `tcp.validnode_checking = YES` and adds your **Windows host IP** to `tcp.invited_nodes`, then bounces the CDB listener.

Without this, the listener rejects DB connections from your Windows box (e.g. SQL Developer) with `ORA-12547: TNS:lost contact`.

## Manual

```bash
. /u01/install/APPS/19.0.0/EBSCDB_apps.env
cd $TNS_ADMIN/EBSDB_apps

cat > sqlnet_ifile.ora <<'EOF'
tcp.validnode_checking = YES
tcp.invited_nodes = (apps.example.com, 192.168.1.100)
EOF

lsnrctl stop  EBSCDB
lsnrctl start EBSCDB
```

Replace `192.168.1.100` with your Windows-host IP. Multiple IPs separated by commas:
```
tcp.invited_nodes = (apps.example.com, 192.168.1.100, 192.168.1.101)
```

## Automated

```bash
./run.sh
```

Reads `HOST_IP` from `../automation/ebs_setup.env`.

## Verify

From **Windows** (PowerShell):
```powershell
Test-NetConnection apps.example.com -Port 1521
```
Should return `TcpTestSucceeded: True`.

Or from the VM:
```bash
tnsping EBSDB
```
Should return `OK (xx msec)`.

## Next

→ [../07_Alter_DB_Users/](../07_Alter_DB_Users/)
