# 16 — AD Utilities

## What it is
The **AD (Applications DBA) utilities** are the command-line tools that maintain the EBS Apps tier. Developers need to know them to compile custom code, apply patches, and recover from failed jobs. All live under `$AD_TOP/bin` (apps tier) and must run as `oracle` with the environment sourced from `EBSapps.env`.

Most used:
- **`adadmin`** — interactive menu for generic maintenance (compile APPS schema, generate messages, JAR files, forms, relink executables, maintain MRC, recreate grants/synonyms).
- **`adpatch`** (11i/12.1) / **`adop`** (12.2) — apply patches.
- **`adctrl`** — review/restart/skip failed worker jobs after a patch fails.
- **`adrelink.sh`** — relink individual executables (e.g. `FNDLIBR`).
- **`adconfig.sh`** — re‑run AutoConfig (regenerate context files and config files).
- **`adpreclone.pl` / `adcfgclone.pl`** — clone source/target (see folder 17).

## How to use

Always start by sourcing the env:

```bash
# On the Apps tier as oracle
cd $APPL_TOP
. ./APPSORA.env                 # 12.1 style
# or on 12.2
. /u01/install/APPS/EBSapps.env run
```

Then run the utility from `$AD_TOP/bin` (it's in `$PATH` once env is sourced).

## Sample

### adadmin — interactive, typical flow after a schema change
```bash
adadmin
# Apps username / password prompted
# Menu path chosen interactively:
#   2. Maintain Applications Files menu
#   4. Regenerate Applications form files
#   1. Generate Oracle Forms files
#
# or:
#   3. Compile/Reload Applications Database Entities menu
#   1. Compile APPS schema                          <-- most common after a patch
```

### adpatch (12.1)
```bash
adpatch \
    workers=4 \
    interactive=no \
    defaultsfile=$APPL_TOP/admin/<SID>/adalldefaults.txt \
    logfile=u12345678.log \
    patchtop=$PWD \
    driver=u12345678.drv
```

### adop (12.2) — Online Patching cycle
```bash
adop phase=prepare
adop phase=apply   patches=12345678
adop phase=finalize
adop phase=cutover
adop phase=cleanup
# or all-in-one:
adop phase=prepare,apply,finalize,cutover,cleanup patches=12345678
```

### adctrl — after a patch worker failed
```bash
adctrl
# Menu:
#   1. Show worker status
#   2. Tell manager that a worker failed its job
#   3. Tell manager that a worker acknowledges quit
#   4. Tell manager to restart a failed worker            <-- most common
#   5. Tell manager to quit
#   6. Tell manager that a worker is on hold
#   7. Tell manager that a worker acknowledges on hold
#   8. Skip a worker (hidden, use only on Oracle Support's advice)
```

### Relink a single executable
```bash
adrelink.sh force=y "fnd FNDLIBR"
adrelink.sh force=y "ar ARXCWMAI"
```

## Next commands
- Safe recovery playbook when `adpatch`/`adop apply` fails mid-run.
- AutoConfig: when to re-run `adconfig.sh`, `$s_custom` file for custom settings.
- Log file locations (`$APPL_TOP/admin/<SID>/log`, `$NE_BASE/EBSapps/log/adop`).
