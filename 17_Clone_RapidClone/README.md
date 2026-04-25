# 17 — Clone (Rapid Clone)

## What it is
**Rapid Clone** is the supported way to copy an EBS instance (DB + Apps) from one environment to another — e.g. **PROD → DEV/TEST**. It regenerates all context-dependent config (hostnames, ports, tablespace paths, service names) so the clone works on a new host.

Two‑phase process:
- On **source**: `adpreclone.pl` — builds clone‑ready stagings (`$COMMON_TOP/clone`, `$ORACLE_HOME/appsutil/clone`).
- Copy source files to target (tar, rsync, or disk image).
- On **target**: `adcfgclone.pl` — prompts for new context values and rebuilds everything.

## How to use

### On the SOURCE instance

As `oracle`, source env, then:

```bash
# 1) DB tier preclone  (run on the DB node)
cd $ORACLE_HOME/appsutil/scripts/<SOURCE_CONTEXT>
perl adpreclone.pl dbTier

# 2) Apps tier preclone  (run on each Apps node)
cd $ADMIN_SCRIPTS_HOME
perl adpreclone.pl appsTier
```

### Copy the staged files

Typical layout to copy to the target host (keep paths/structure):

```
Source DB tier:
    $ORACLE_HOME/appsutil/clone/          → target DB tier
    DB datafiles, redo logs, controlfiles → target DB tier
Source Apps tier:
    $COMMON_TOP/clone/                    → target Apps tier
    $APPL_TOP                             → target Apps tier
    $ORACLE_HOME (iAS 10.1.2, 10.1.3)     → target Apps tier
```

### On the TARGET instance

```bash
# 1) Configure DB tier (shuts down any running source DB; brings up a new one)
cd $ORACLE_HOME/appsutil/clone/bin
perl adcfgclone.pl dbTier           # prompts: target SID, host, ports, data/index top, apps password

# 2) Configure Apps tier
cd $COMMON_TOP/clone/bin
perl adcfgclone.pl appsTier         # prompts: context name, ports, target DB connect string
```

After `adcfgclone.pl appsTier` finishes, it auto-starts the services. Log in and validate.

## Sample session (target apps tier, abbreviated)

```
$ perl adcfgclone.pl appsTier
Provide the APPS password : *********
Target System Hostname                     : devapps01
Target System Database SID                 : DEV
Target System Database Server Node         : devdb01
Target System Database Domain Name         : example.com
Target System Base Directory               : /u01/install/APPS
...
Do you want to preserve the port values from the source
system on the target system (y/n) [y] ?    : n
Target System Port Pool [0-99]             : 3
...
AutoConfig is running on target ...
Starting OPMN managed OC4J processes ...
Apps Tier has been cloned successfully.
```

## Post-clone cleanup (developer-relevant)
- Scramble/mask PROD data (emails, payroll, banking) in the target.
- Purge Workflow notifications: `begin wf_purge.Total; end;` + disable mailer.
- Invalidate scheduled concurrent requests: `UPDATE fnd_concurrent_requests SET phase_code='C', status_code='D' WHERE phase_code='P';`
- Reset passwords for known users if needed.

## Next commands
- Script the scrambling/cleanup post-clone (Workflow, concurrent requests, printers, profile URLs).
- Cold vs hot clone techniques and their trade-offs.
- Typical adcfgclone failure points and fixes (port conflicts, context file issues).
