# 19 — XDOLoader (BI Publisher Template Migration)

## What it is
`XDOLoader` is a Java utility that moves **BI Publisher artifacts** (Data Definitions, Templates — RTF/XSL/PDF, sub-templates) between EBS instances. Templates are stored as blobs in `XDO_LOBS`, so you can't use FNDLOAD for them — `XDOLoader` is the supported tool.

Lives in `$JAVA_TOP/oracle/apps/xdo/oa/util/XDOLoader.class`.

## How to use

Always run on the Apps tier as `oracle` with env sourced. Two main operations: `DOWNLOAD` and `UPLOAD`. A separate call is needed per artifact type (`TEMPLATE`, `DATA_TEMPLATE`, etc.).

### UPLOAD a Data Definition
```bash
java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
  -DB_USERNAME apps \
  -DB_PASSWORD <apps_pwd> \
  -JDBC_CONNECTION "apps.example.com:1521:VIS" \
  -LOB_TYPE DATA_TEMPLATE \
  -APPS_SHORT_NAME XXC \
  -LOB_CODE XXC_EMP_RPT \
  -LANGUAGE en \
  -TERRITORY US \
  -XDO_FILE_TYPE XML \
  -FILE_NAME XXC_EMP_RPT.xml
```

### UPLOAD an RTF template
```bash
java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
  -DB_USERNAME apps \
  -DB_PASSWORD <apps_pwd> \
  -JDBC_CONNECTION "apps.example.com:1521:VIS" \
  -LOB_TYPE TEMPLATE_SOURCE \
  -APPS_SHORT_NAME XXC \
  -LOB_CODE XXC_EMP_RPT \
  -LANGUAGE en \
  -TERRITORY US \
  -XDO_FILE_TYPE RTF \
  -FILE_NAME XXC_EMP_RPT.rtf \
  -NLS_LANG American_America.UTF8
```

### DOWNLOAD everything for an application (for migration)
```bash
java oracle.apps.xdo.oa.util.XDOLoader DOWNLOAD \
  -DB_USERNAME apps \
  -DB_PASSWORD <apps_pwd> \
  -JDBC_CONNECTION "apps.example.com:1521:VIS" \
  -APPS_SHORT_NAME XXC \
  -LOB_TYPE TEMPLATE_SOURCE \
  -LOG_FILE xdoload_down.log
# Writes files into the current directory named by LOB_CODE.
```

## Sample — end-to-end promote a BIP report

```bash
# -------- On SOURCE (DEV) --------
mkdir /tmp/bip_xxc_emp && cd /tmp/bip_xxc_emp

# 1) Data Definition
java oracle.apps.xdo.oa.util.XDOLoader DOWNLOAD \
  -DB_USERNAME apps -DB_PASSWORD $APPS_PWD \
  -JDBC_CONNECTION "dev.example.com:1521:DEV" \
  -APPS_SHORT_NAME XXC -LOB_TYPE DATA_TEMPLATE \
  -LOB_CODE XXC_EMP_RPT -LANGUAGE en -TERRITORY US

# 2) RTF Template
java oracle.apps.xdo.oa.util.XDOLoader DOWNLOAD \
  -DB_USERNAME apps -DB_PASSWORD $APPS_PWD \
  -JDBC_CONNECTION "dev.example.com:1521:DEV" \
  -APPS_SHORT_NAME XXC -LOB_TYPE TEMPLATE_SOURCE \
  -LOB_CODE XXC_EMP_RPT -LANGUAGE en -TERRITORY US

tar -cvf xxc_emp_bip.tar .

# -------- On TARGET (TEST) --------
cd /tmp && tar -xvf xxc_emp_bip.tar -C /tmp/bip_xxc_emp/
cd /tmp/bip_xxc_emp/

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
  -DB_USERNAME apps -DB_PASSWORD $APPS_PWD \
  -JDBC_CONNECTION "test.example.com:1521:TEST" \
  -APPS_SHORT_NAME XXC -LOB_TYPE DATA_TEMPLATE \
  -LOB_CODE XXC_EMP_RPT -LANGUAGE en -TERRITORY US \
  -XDO_FILE_TYPE XML -FILE_NAME XXC_EMP_RPT.xml

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
  -DB_USERNAME apps -DB_PASSWORD $APPS_PWD \
  -JDBC_CONNECTION "test.example.com:1521:TEST" \
  -APPS_SHORT_NAME XXC -LOB_TYPE TEMPLATE_SOURCE \
  -LOB_CODE XXC_EMP_RPT -LANGUAGE en -TERRITORY US \
  -XDO_FILE_TYPE RTF -FILE_NAME XXC_EMP_RPT.rtf
```

Don't forget: also move the **Data Definition / Template registration rows** in `XDO_DS_DEFINITIONS_B` / `XDO_TEMPLATES_B` — these are moved by XDOLoader automatically when the `.xml`/`.rtf` is uploaded under the correct `LOB_CODE`.

## Next commands
- Full `LOB_TYPE` matrix (`XML_SCHEMA`, `BURSTING_FILE`, `SUB_TEMPLATE`, ...).
- Wrapper script to migrate ALL templates for an application in one call.
- Combine with FNDLOAD (concurrent program) so the report + template deploy together.
