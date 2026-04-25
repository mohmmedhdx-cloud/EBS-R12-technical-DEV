# Phase 05 — Verify Password-Change Logs

**Run as:** `oracle` &nbsp;&nbsp; **Time:** seconds

## What it does
Greps the FNDCPASS log files produced by phases 02-04 for success lines, and scans them for any `error`, `failed`, or `invalid` keywords.

## Manual

```bash
cd ~/log
grep 'changed successfully' L*.log
egrep -i 'error|failed|invalid' L*.log
```

## Automated

```bash
./run.sh
```

Exits non-zero if anything matches the error pattern.

## What to expect
- ~40 `changed successfully for user <NAME>` lines (one per demo user).
- 1 line: `ALLORACLE passwords changed successfully.`
- Zero output from the error-scan command.

If the error scan produces matches, **stop and investigate** before going further — the most common cause is an interrupted run or a wrong EBS_SYSTEM password entered in phase 04.

## Next

→ [../06_Configure_Sqlnet/](../06_Configure_Sqlnet/)
