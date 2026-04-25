# 18 — FNDLOAD

## What it is
**FNDLOAD** is the command‑line tool for moving **AOL metadata** between EBS instances as text (`.ldt`) files — so you can version‑control them in Git, promote from DEV → TEST → PROD, and roll back. It's driven by a **configuration file (`.lct`)** that describes which tables/columns to extract.

Works for: Concurrent Programs, Value Sets, Menus, Responsibilities, Messages, Lookups, Profile Options, Request Groups, Forms Personalizations, OAF Personalizations, Alerts, Workflows, and more.

## How to use

Syntax (download from source):
```bash
FNDLOAD <apps>/<pwd> 0 Y DOWNLOAD <lct-file> <output.ldt> <entity> [params]
```

Syntax (upload to target):
```bash
FNDLOAD <apps>/<pwd> 0 Y UPLOAD <lct-file> <input.ldt>  [ - <warn=mode> ]
```

- `0 Y` = `UPLOAD_MODE` default, `WARNINGS_ON`.
- `.lct` files live in `$FND_TOP/patch/115/import/` and each product's `patch/115/import/`.

## Sample — the most-used commands

### Concurrent program (definition + executable + parameters)
```bash
# Download
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct \
    XXC_EMP_LOG_CP.ldt PROGRAM APPLICATION_SHORT_NAME='XXC' CONCURRENT_PROGRAM_NAME='XXC_EMP_LOG'

# Upload on target
FNDLOAD apps/<pwd> 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct XXC_EMP_LOG_CP.ldt
```

### Value set
```bash
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/afffload.lct \
    XXC_VS_DEPT.ldt VALUE_SET FLEX_VALUE_SET_NAME='XXC_DEPT_VS'
FNDLOAD apps/<pwd> 0 Y UPLOAD   $FND_TOP/patch/115/import/afffload.lct XXC_VS_DEPT.ldt
```

### Menu
```bash
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/afsload.lct \
    XXC_MAIN_MENU.ldt MENU MENU_NAME='XXC_MAIN_MENU'
```

### Responsibility (definition; does **not** include menu/request group — download those separately)
```bash
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/afscursp.lct \
    XXC_HR_MGR_RESP.ldt FND_RESPONSIBILITY RESP_KEY='XXC_HR_MANAGER'
```

### Lookup
```bash
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/aflvmlu.lct \
    XXC_RISK_LEVEL_LK.ldt FND_LOOKUP_TYPE APPLICATION_SHORT_NAME='XXC' LOOKUP_TYPE='XXC_RISK_LEVEL'
```

### Profile option (definition)
```bash
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/afscprof.lct \
    XXC_DEF_WH_PROF.ldt PROFILE PROFILE_NAME='XXC_DEFAULT_WAREHOUSE'
```

### Forms Personalization
```bash
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/afsload.lct \
    XXC_PEOPLE_PERS.ldt FND_FORM_CUSTOM_RULES FUNCTION_NAME='PERWSHRG'
```

### OAF Personalization (JDR)
```bash
# Download
java oracle.jrad.tools.xml.exporter.XMLExporter \
    /oracle/apps/per/selfservice/newhire/webui/customizations/site/0/ReviewPG \
    -username apps -password <pwd> \
    -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=apps.example.com)(PORT=1521))(CONNECT_DATA=(SID=VIS)))" \
    -rootdir $XXC_TOP/patch/115 -rootpackage /oracle/apps
```

## Sample — a reusable shell wrapper

```bash
#!/bin/bash
# xxc_fndload_cp.sh  APPS_PWD  CP_SHORT_NAME  DIRECTION(DOWNLOAD|UPLOAD)  LDT
APPS_PWD=$1 ; NAME=$2 ; DIR=$3 ; LDT=$4
LCT=$FND_TOP/patch/115/import/afcpprog.lct

if [ "$DIR" = "DOWNLOAD" ]; then
  FNDLOAD apps/$APPS_PWD 0 Y DOWNLOAD $LCT $LDT PROGRAM \
          APPLICATION_SHORT_NAME=XXC CONCURRENT_PROGRAM_NAME=$NAME
else
  FNDLOAD apps/$APPS_PWD 0 Y UPLOAD   $LCT $LDT
fi
```

## Tips
- `.ldt` files are plain text — safe to commit to Git.
- Use `CUSTOM_MODE=FORCE` as an extra param on UPLOAD to overwrite non-custom values (use with care).
- Always extract children *and* parents — e.g. a Responsibility LDT alone won't bring its Menu or Request Group.

## Next commands
- Full `.lct` → entity cheat sheet (which LCT file controls what).
- Build a Git layout for storing `.ldt` artifacts per module.
- CI job that uploads LDTs to a shared DEV on every merge.
