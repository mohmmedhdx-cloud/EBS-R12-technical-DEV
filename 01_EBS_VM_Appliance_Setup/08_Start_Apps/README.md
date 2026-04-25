# Phase 08 — Start Apps Tier

**Run as:** `root` &nbsp;&nbsp; **Time:** 5-15 minutes

## What it does
Starts every app-tier process, in this order:
1. Fulfillment Server (`jtffmctl.sh`) — port 9300
2. OPMN (`adopmnctl.sh`)
3. Oracle HTTP Server (`adapcctl.sh`) — port 8000
4. Node Manager (`adnodemgrctl.sh`)
5. Forms listener (`adalnctl.sh`)
6. Internal Concurrent Manager (`adcmctl.sh`)
7. WebLogic AdminServer (`adadminsrvctl.sh`) — port 7001
8. Managed servers: `forms_server1`, `oafm_server1`, `oacore_server1`

Each service prints `exiting with status 0` on success.

## Manual

```bash
service apps start
```

## Automated

```bash
./run.sh
```

## Verify

As `oracle`:
```bash
. /u01/install/APPS/EBSapps.env run
adopmnctl.sh status
ps -ef | grep -E 'FNDLIBR|java|opmn|httpd' | grep -v grep | wc -l
```

From **Windows**:
```powershell
Test-NetConnection apps.example.com -Port 8000
```

Open in a browser: `http://apps.example.com:8000/OA_HTML/AppsLogin` — at this point the login page should load (but you haven't changed the WebLogic password yet; concurrent manager should be up).

## Next

→ [../09_Update_WebLogic/](../09_Update_WebLogic/)
