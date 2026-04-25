# Phase 01 — Start the Container Database

**Run as:** `root` &nbsp;&nbsp; **Time:** ~1 minute

## What it does
Starts the 19c container database (CDB = `EBSCDB`) and its listener on port 1521. Internally runs `adcdbctl.sh start` + `adcdblnctl.sh start` via the SysV-style init wrapper `/etc/init.d/ebscdb`.

## Manual

```bash
service ebscdb start
```

Expected output ends with:
- `Database opened.`
- `Listener service EBSDB started.`
- `adcdblnctl.sh: exiting with status 0`

## Automated

```bash
./run.sh
```

## Verify

```bash
ps -ef | grep -i pmon | grep -v grep      # should show ora_pmon_EBSCDB
lsnrctl status EBSCDB                      # should list service EBSDB
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ORA-01102: cannot mount database in EXCLUSIVE mode` | stale lk/pid file | `rm $ORACLE_HOME/dbs/lk* /tmp/.oracle*`, retry |
| Listener fails to start | port 1521 already in use | `ss -tlnp \| grep 1521` |

## Next

→ [../02_Enable_SYSADMIN/](../02_Enable_SYSADMIN/)
