# 01 — EBS VM Appliance Setup (Oracle VirtualBox)

## What it is
Oracle ships a downloadable **Oracle VM VirtualBox Appliance for EBS R12.2** as an `.ova` file. Importing it gives you a pre-installed, pre-configured dual-node (DB + Apps) EBS instance you can run locally for development and learning.

This folder contains the **full post-import configuration**, broken into one folder per step. Each step is self-contained: its `README.md` has the manual instructions; its `run.sh` (where applicable) is the automated version.

## Step-by-step — run in order

| # | Step | As | Kind |
|---|---|---|---|
| 00 | [VM Config and First Boot](00_VM_Config_and_First_Boot/) | Windows | Manual only — import OVA, Bridged network, first-boot prompts (root/oracle passwords + `VISION`), connect via MobaXterm |
| 01 | [Start Container DB](01_Start_DB/) | root | `service ebscdb start` |
| 02 | [Enable SYSADMIN](02_Enable_SYSADMIN/) | oracle | set SYSADMIN password |
| 03 | [Enable Demo Users](03_Enable_Demo_Users/) | oracle | set ~40 demo user passwords |
| 04 | [Change DB Passwords](04_Change_DB_Passwords/) | oracle | rotate product schemas + EBS_SYSTEM |
| 05 | [Verify Logs](05_Verify_Logs/) | oracle | grep success / errors |
| 06 | [Configure SQL\*Net](06_Configure_Sqlnet/) | oracle | write `sqlnet_ifile.ora` + bounce listener |
| 07 | [Alter DB Users](07_Alter_DB_Users/) | oracle | sqlplus: alter SYS / SYSTEM / EBS_SYSTEM |
| 08 | [Start Apps Tier](08_Start_Apps/) | root | `service apps start` |
| 09 | [Update WebLogic](09_Update_WebLogic/) | oracle | `welcome1` → `Welcome01` |
| 10 | [Disable Firewall](10_Disable_Firewall/) | root | `systemctl disable firewalld` |
| 99 | [Enable ISG](99_Enable_ISG/) | oracle | **optional** — Integrated SOA Gateway |

Shared driver + helpers live in [automation/](automation/).

## Run everything with one command

After step 0 is done (VM reachable via SSH as both `root` and `oracle`):

👉 **Follow the end-to-end guide: [QUICKSTART.md](QUICKSTART.md)** — a single-page walkthrough with test/verification commands after each step.

See also [automation/README.md](automation/README.md) for the reference on all env vars and flags.

## Credentials after setup

| Where | User | Password |
|---|---|---|
| Linux | `root`, `oracle` | `password` |
| DB CDB | `SYS`, `SYSTEM` | `password` |
| DB PDB=EBSDB | `EBS_SYSTEM` | `password` (was `manager`) |
| DB **APPS**, **APPLSYS**, APPS_NE, APPLSYSPUB | — | `apps` (default, **not** changed) |
| DB product schemas (AP, AR, GL, INV, HR, …) | — | `password` |
| EBS | `SYSADMIN` + demo users | `password` |
| WebLogic | `weblogic` | `Welcome01` (was `welcome1`) |

## Instance identifiers (shipped values)

- CDB: **`EBSCDB`** (Linux service: `ebscdb`)
- PDB: **`EBSDB`** (the app service / SID)
- Context: **`EBSDB_apps`**
- DB host: **`apps.example.com`**
- Instance label entered at first boot: **`VISION`**

## Next commands

- Add a post-boot health-check script (listener, DB open, OPMN, concurrent managers).
- Clean-shutdown helper (`adstpall.sh` → `service ebscdb stop`) for snapshotting.
- Document the most common first-boot issues (hostname mismatch, clock skew after VM pause, OPMN won't start).
