# Phase 09 — Update WebLogic Admin Password

**Run as:** `oracle` &nbsp;&nbsp; **Time:** 10-20 minutes

## What it does
Rotates the WebLogic admin password from the shipped `welcome1` → `Welcome01`. Three sub-steps:

1. **Stop mid-tier** with `adstpall.sh -skipNM -skipAdmin` — leaves Node Manager + AdminServer running so `txkUpdateEBSDomain.pl` can talk to WLS.
2. **Change the password** with `txkUpdateEBSDomain.pl -action=updateAdminPassword`.
3. **Restart everything** with `adstrtal.sh` using the new password.

## Manual

### 9.1 — Stop mid-tier
```bash
. /u01/install/APPS/EBSapps.env run
adstpall.sh -skipNM -skipAdmin
```
| Prompt | Answer |
|---|---|
| Enter the APPS username: | `apps` |
| Enter the APPS password: | `apps` |
| Enter the WebLogic Server password: | `welcome1` (current) |

### 9.2 — Change WLS password
```bash
perl $FND_TOP/patch/115/bin/txkUpdateEBSDomain.pl -action=updateAdminPassword
```
| Prompt | Answer |
|---|---|
| Enter "Yes" to proceed or anything else to exit: | `YES` |
| Enter the full path of Applications Context File [DEFAULT - …]: | *(press Enter)* |
| Enter the WLS Admin Password: | `welcome1` (current) |
| Enter the new WLS Admin Password: | `Welcome01` |
| Enter the APPS user password: | `apps` |

Success message: `WebLogic Admin Password is changed. Restart all application tier services using control scripts.`

> ⚠ If you see `ERROR: Invalid WLS Admin user credentials.` — you typed the current WLS password wrong. Just re-run the same command; nothing is broken.

### 9.3 — Restart the full tier
```bash
adstrtal.sh
```
| Prompt | Answer |
|---|---|
| Enter the APPS username: | `apps` |
| Enter the APPS password: | `apps` |
| Enter the WebLogic Server password: | `Welcome01` ← **new** one now |

## Automated

```bash
./run.sh
```

Reads `APPS_PASSWORD`, `CURRENT_WLS_PASSWORD`, `NEW_WLS_PASSWORD` from `../automation/ebs_setup.env`. All three sub-steps are driven by `expect`, so no typos are possible.

## Verify

Open `http://apps.example.com:7001/console` → log in as `weblogic / Welcome01` → should land in the WLS Admin Console.

Also check managed servers are up:
```bash
. /u01/install/APPS/EBSapps.env run
adopmnctl.sh status
```

## Next

→ [../10_Disable_Firewall/](../10_Disable_Firewall/)
