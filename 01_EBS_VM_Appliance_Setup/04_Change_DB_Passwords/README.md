# Phase 04 — Change DB Product-Schema Passwords

**Run as:** `oracle` &nbsp;&nbsp; **Time:** 1-3 minutes

## What it does
Runs `FNDCPASS apps/apps SYSTEM/<system_pw> ALLORACLE <new_pw>` under the hood. Rotates the passwords of every **product schema** (AP, AR, GL, INV, HR, PO, …) to the new value.

Also verifies + sets the `EBS_SYSTEM` password (the shipped default is `manager`; it must be supplied correctly so the script can authenticate before rotating).

**Not changed by this step:** `APPS`, `APPLSYS`, `APPS_NE`, `APPLSYSPUB` — `ALLORACLE` mode deliberately skips those four. They stay at their shipped default (`apps`).

## Manual

```bash
cd ~/log
/u01/install/APPS/scripts/changeDBpasswords.sh
```

Prompts:

| Prompt | Answer |
|---|---|
| Enter new password for base product schemas: | `password` |
| Re-enter password for base product schemas: | `password` |
| Enter password for EBS_SYSTEM: | `manager` ← **current** default, not the new one |

## Automated

```bash
./run.sh
```

## Verify

```bash
grep 'ALLORACLE passwords changed successfully' ~/log/L*.log
```

Should print one matching line.

## Next

→ [../05_Verify_Logs/](../05_Verify_Logs/)
