# Phase 02 — Enable SYSADMIN EBS User

**Run as:** `oracle` &nbsp;&nbsp; **Time:** ~30 seconds

## What it does
Activates the `SYSADMIN` EBS Applications user (the System Administrator account) and sets a new password. Internally calls `FNDCPASS` under the hood.

## Manual

```bash
mkdir -p ~/log && cd ~/log
/u01/install/APPS/scripts/enableSYSADMIN.sh
```

Prompts:

| Prompt | Answer |
|---|---|
| Enter new password for SYSADMIN: | `password` |
| Re-enter password for SYSADMIN: | `password` |

Produces `L*.log` and `O*.out` in `~/log`.

## Automated

```bash
./run.sh
```

Reads `NEW_PASSWORD` from `../automation/ebs_setup.env`.

## Verify

```bash
grep 'changed successfully' ~/log/L*.log | grep SYSADMIN
```

You should see one line: `Password is changed successfully for user SYSADMIN.`

## Next

→ [../03_Enable_Demo_Users/](../03_Enable_Demo_Users/)
