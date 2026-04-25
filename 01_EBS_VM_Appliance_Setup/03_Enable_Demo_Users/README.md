# Phase 03 — Enable Vision Demo Users

**Run as:** `oracle` &nbsp;&nbsp; **Time:** 5-10 minutes

## What it does
Activates ~40 Vision demo EBS users (OPERATIONS, PHENRY, CBROWN, KJONES, DBAKER, BWEBB, RBATES, APOTTER, MGRMKT, MFG, HRMS, CONMGR, PSTOCK, SPAIN, DLYON, …) and sets them all to the same password. Each user gets its own `L*.log` / `O*.out` in `~/log`.

## Manual

```bash
cd ~/log
/u01/install/APPS/scripts/enableDEMOusers.sh
```

Prompts:

| Prompt | Answer |
|---|---|
| Enter new password for DEMO users: | `password` |
| Re-enter password for DEMO users: | `password` |

## Automated

```bash
./run.sh
```

## Verify

```bash
grep -c 'changed successfully' ~/log/L*.log | wc -l       # ~40 log files
grep 'changed successfully for user OPERATIONS' ~/log/L*.log
```

## Next

→ [../04_Change_DB_Passwords/](../04_Change_DB_Passwords/)
