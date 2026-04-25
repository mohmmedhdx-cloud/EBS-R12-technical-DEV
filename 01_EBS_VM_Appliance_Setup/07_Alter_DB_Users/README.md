# Phase 07 — Alter DB Users (SYS, SYSTEM, EBS_SYSTEM)

**Run as:** `oracle` &nbsp;&nbsp; **Time:** seconds

## What it does
Sets the DB-tier admin passwords via `sqlplus / as sysdba`:
- `SYS` and `SYSTEM` in the **CDB** (`EBSCDB`)
- `EBS_SYSTEM` inside the **PDB** (`EBSDB`)

## Manual

```bash
sqlplus / as sysdba
```

Then in SQL*Plus:
```sql
ALTER USER SYSTEM IDENTIFIED BY password;
ALTER USER SYS    IDENTIFIED BY password;
SHOW PDBS;
ALTER SESSION SET CONTAINER = EBSDB;
ALTER USER EBS_SYSTEM IDENTIFIED BY password;
EXIT;
```

`SHOW PDBS` should list `EBSDB` with `OPEN MODE = READ WRITE`.

## Automated

```bash
./run.sh
```

## Verify

```bash
sqlplus system/password@EBSDB <<< 'SELECT USER FROM DUAL;'
sqlplus sys/password@EBSDB as sysdba <<< 'SELECT NAME FROM V\$DATABASE;'
```

Both should succeed.

## Next

→ [../08_Start_Apps/](../08_Start_Apps/)
