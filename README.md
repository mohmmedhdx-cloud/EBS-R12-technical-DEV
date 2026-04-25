# EBS R12 Technical Development — Reference Project

A hands-on reference for the Oracle E-Business Suite R12 technical development stack, built and verified against a live Vision 12.2.12 instance.

Each section is self-contained: short README, runnable code/scripts, and verified examples.

## Sections

### [01_EBS_VM_Appliance_Setup](01_EBS_VM_Appliance_Setup/)
End-to-end automation that turns a freshly-imported Vision OVA into a running EBS instance in ~25 minutes. 10 numbered phases (start DB, enable SYSADMIN, change passwords, configure sqlnet, start apps, update WebLogic, etc.) plus an `automation/` driver script that runs them all unattended. Includes [QUICKSTART.md](01_EBS_VM_Appliance_Setup/QUICKSTART.md).

### [02_PLSQL_SQL_INTEGRATION](02_PLSQL_SQL_INTEGRATION/)
- **Base Tables** — canonical tables + tested joins per module (HRMS, AP, AR, GL, INV, PO, OM, FND). Every query verified against the live Vision DB.
- **Oracle APIs** — 8 write-ups for the most-used public packages (`fnd_global`, `hr_employee_api`, `ap_vendor_pub_pkg`, `hz_party_v2pub` chain, `ar_invoice_api_pub`, `inv_item_grp`, `oe_order_pub`, `po_document_control_pub`). Every sample executed end-to-end and returned real IDs.
- **Examples** — full Fusion → OIC → EBS supplier-creation integration: staging table, persistent error log, PL/SQL wrapper around `ap_vendor_pub_pkg.create_vendor`, OIC mapping + Switch + Throw Fault. Verified live (a real `ap_suppliers` row was created from a real Fusion event).

## Roadmap

More sections will be added as separate folders, each delivered as a complete unit (concept → working code → verification):

- Concurrent Programs (executable + parameters + value sets)
- Reports / BI Publisher (data definition + RTF + XML output)
- WebADI (integrators + layouts + spreadsheet upload)
- OAF Development + Personalization
- Forms Personalization
- Workflow (Builder + notifications)
- Alerts, Flexfields, Lookups, Profile Options, AOL/FND
- AD Utilities, Clone, FNDLOAD, XDOLoader

When each is ready it lands here as `0X_<Topic>/`.

## Publishing

- [LINKEDIN_POST.md](LINKEDIN_POST.md) — draft posts for sharing milestones.
- [PUBLISHING_TO_GITHUB.md](PUBLISHING_TO_GITHUB.md) — git workflow walkthrough.
- `.gitignore` excludes `ebs_setup.env`, logs, Oracle wallets, and local memory dirs.
- `.gitattributes` keeps `.sh` files at LF so they run cleanly on the EBS VM.

## License

[MIT](LICENSE)
