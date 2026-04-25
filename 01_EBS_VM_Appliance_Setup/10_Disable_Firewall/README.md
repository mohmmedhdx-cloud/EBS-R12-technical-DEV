# Phase 10 — Disable Firewalld

**Run as:** `root` &nbsp;&nbsp; **Time:** seconds

## What it does
Stops and permanently disables `firewalld` so the EBS service ports are reachable from the Windows host:

| Port | Service |
|---|---|
| 1521 | Database listener |
| 7001 | WebLogic admin console |
| 8000 | Oracle HTTP Server (EBS UI) |
| 9300 | Fulfillment Server |

For a local demo VM, disabling firewalld entirely is simpler than opening each port individually. For anything public-facing, configure `firewall-cmd` zones instead.

## Manual

```bash
systemctl stop    firewalld
systemctl disable firewalld
systemctl status  firewalld         # expect: Active: inactive (dead)
```

## Automated

```bash
./run.sh
```

## Verify

From **Windows** PowerShell:
```powershell
Test-NetConnection apps.example.com -Port 1521    # DB
Test-NetConnection apps.example.com -Port 7001    # WLS
Test-NetConnection apps.example.com -Port 8000    # EBS UI
```
All three should return `TcpTestSucceeded: True`.

## Next

**Setup complete.** Open [http://apps.example.com:8000/OA_HTML/AppsLogin](http://apps.example.com:8000/OA_HTML/AppsLogin) and log in as **SYSADMIN / password** (or **OPERATIONS / password**).

Optional step → [../99_Enable_ISG/](../99_Enable_ISG/) (only if you plan to use Integrated SOA Gateway).
