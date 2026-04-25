# EBS R12 Technical Development — Reference Project

A hands-on reference covering the full Oracle E‑Business Suite R12 technical development stack, from booting the VM appliance to every major development track.

Each folder is a self‑contained topic with a short README explaining **what it is**, **how to use it**, and a **sample**. Deeper content (full code, walkthroughs, screenshots) is added per topic in its own dedicated command.

## Index

### Environment
- [01_EBS_VM_Appliance_Setup](01_EBS_VM_Appliance_Setup/) — import OVA into VirtualBox and start the EBS services.

### Core technical tracks
- [02_PLSQL_SQL_INTEGRATION](02_PLSQL_SQL_INTEGRATION/) — base tables + joins per module (verified live), Oracle public APIs (HRMS/AP/AR/INV/OM/PO/FND), and an end-to-end Fusion → OIC → EBS supplier-creation example.
- [03_Concurrent_Programs](03_Concurrent_Programs/) — executables, parameters, value sets, submission.
- [04_Reports_BIPublisher](04_Reports_BIPublisher/) — Data Definitions, RTF templates, XML output.
- [05_WebADI](05_WebADI/) — Integrators, Layouts, Mappings, spreadsheet uploads.
- [06_OAF_Development](06_OAF_Development/) — OA Framework pages, CO/AM/VO/EO in JDeveloper.
- [07_OAF_Personalization](07_OAF_Personalization/) — runtime personalization via "Personalize Page".
- [08_Forms_Personalization](08_Forms_Personalization/) — Oracle Forms runtime rules.
- [09_Workflow](09_Workflow/) — Workflow Builder, notifications, approvals.

### Setup & misc technical
- [10_APIs_and_Interfaces](10_APIs_and_Interfaces/) — seeded Oracle APIs + open interface tables.
- [11_Alerts](11_Alerts/) — Event and Periodic alerts.
- [12_Flexfields](12_Flexfields/) — KFF and DFF registration and validation.
- [13_Lookups](13_Lookups/) — FND lookup types and values.
- [14_Profile_Options](14_Profile_Options/) — hierarchy and runtime access.
- [15_AOL_FND_Basics](15_AOL_FND_Basics/) — users, responsibilities, menus, functions.

### DBA‑side utilities a developer needs
- [16_AD_Utilities](16_AD_Utilities/) — adadmin, adpatch, adctrl.
- [17_Clone_RapidClone](17_Clone_RapidClone/) — adpreclone + adcfgclone.
- [18_FNDLOAD](18_FNDLOAD/) — metadata migration between instances.
- [19_XDOLoader](19_XDOLoader/) — BI Publisher template migration.

## How to use this repo

Pick a folder, read its README, try the sample in a sandbox VM instance, then ask me to deepen that specific topic — e.g. *"expand folder 03 with a full concurrent program example including a value set and a PL/SQL executable"*.

> **Fully working today:** [01_EBS_VM_Appliance_Setup](01_EBS_VM_Appliance_Setup/) — end-to-end automation that turns a freshly-imported Vision OVA into a running EBS instance in ~25 minutes. See [QUICKSTART](01_EBS_VM_Appliance_Setup/QUICKSTART.md).
>
> **Also fully built:** [02_PLSQL_SQL_INTEGRATION](02_PLSQL_SQL_INTEGRATION/) — base tables (HRMS, AP, AR, GL, INV, PO, OM, FND), 8 verified Oracle API write-ups, and the Fusion → OIC → EBS supplier integration example.
>
> **Other 17 folders:** concept + how-to + sample snippet per topic; full working code is added per-topic on demand.

## Publishing

- [LINKEDIN_POST.md](LINKEDIN_POST.md) — two draft posts announcing the VM automation (short and long versions).
- [PUBLISHING_TO_GITHUB.md](PUBLISHING_TO_GITHUB.md) — step-by-step guide to create the GitHub repo, commit, and push.
- `.gitignore` excludes `ebs_setup.env`, logs, Oracle wallets, and local Claude/memory dirs.
