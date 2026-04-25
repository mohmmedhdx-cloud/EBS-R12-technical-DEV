# 02 — PL/SQL in EBS R12

Two reference tracks live under this folder — both **verified against a live Vision R12.2.12 instance** before shipping:

## [Oracle_APIs/](Oracle_APIs/) — seeded public APIs (tested)

Eight files covering the most commonly used EBS public packages, each with a copy-paste-runnable sample that was executed end-to-end against the live VM and returned real IDs:

| # | File | Package(s) |
|---|---|---|
| 1 | [01_FND_Utilities.md](Oracle_APIs/01_FND_Utilities.md) | `fnd_global`, `fnd_profile`, `fnd_message`, `fnd_file`, `fnd_request` |
| 2 | [02_HRMS_Employee.md](Oracle_APIs/02_HRMS_Employee.md) | `hr_employee_api`, `hr_person_api`, `hr_ex_employee_api` |
| 3 | [03_AP_Supplier.md](Oracle_APIs/03_AP_Supplier.md) | `ap_vendor_pub_pkg` |
| 4 | [04_AR_Customer_TCA.md](Oracle_APIs/04_AR_Customer_TCA.md) | `hz_party_v2pub`, `hz_cust_account_v2pub`, `hz_location_v2pub`, `hz_party_site_v2pub`, `hz_cust_account_site_v2pub` |
| 5 | [05_AR_Invoice_Receipt.md](Oracle_APIs/05_AR_Invoice_Receipt.md) | `ar_invoice_api_pub`, `ar_receipt_api_pub` |
| 6 | [06_INV_Item.md](Oracle_APIs/06_INV_Item.md) | `inv_item_grp`, `ego_item_pub`, `inv_txn_manager_pub` |
| 7 | [07_OM_Order.md](Oracle_APIs/07_OM_Order.md) | `oe_order_pub` |
| 8 | [08_PO_Document_Control.md](Oracle_APIs/08_PO_Document_Control.md) | `po_document_control_pub` |

Rule of thumb: **never `INSERT` directly into EBS seeded tables** — always go through the relevant API so validations, MOAC, flexfield rules, history rows, and business-event triggers fire.

## [Base_Tables/](Base_Tables/) — base tables + joins per module

Canonical base tables + tested joins for each module (HRMS, AP, AR, GL, INV, PO, OM, FND). **Every table and every query was executed against the live Vision instance** — if it's listed, it exists and the samples return rows. MOAC / OU filter guidance included per module.

## [Examples/](Examples/) — end-to-end scenarios

- [01_Fusion_to_EBS_Supplier_via_OIC.md](Examples/01_Fusion_to_EBS_Supplier_via_OIC.md) — **Built + verified end-to-end** on the Vision instance. Event-driven supplier creation **Fusion → OIC → EBS**. OIC subscribes to the Fusion `supplierCreated` business event, INSERTs into `APPS.XXC_SUPPLIER_HEADER_STG`, synchronously calls `APPS.XX_LOAD_SUP_EBS.Process_sups_api(request_id, Res_out)` which wraps `ap_vendor_pub_pkg.create_vendor`, and branches on `Res_out` in OIC (Success path / Throw Fault). Full DDL, package source, OIC flow + mapping + Switch logic, verification, monitoring, and a LinkedIn-ready summary. A real `ap_suppliers` row (`vendor_id=40178`) was created from a real Fusion event.

## How to run anything in here

From Claude's Windows host (local Oracle XE sqlplus installed):
```bash
sqlplus -S apps/apps@//<ebs-host>:1521/EBSDB
```

From the VM as `oracle`:
```bash
sqlplus apps/apps@EBSDB
```

Then either `@` an SQL file or paste the block interactively.
