# Oracle EBS R12 — Public APIs (tested)

Every API on this page was executed against a live Vision R12.2.12 instance before being documented. Sample calls are copy-paste runnable on a Vision VM and wrap side-effecting work in `p_commit => g_false` + `ROLLBACK` so you can try them without leaving residue.

## Why use public APIs (and not direct DML)

Oracle's public packages handle things your custom code won't think of:
- MOAC (multi-org) policy application
- Flexfield validation, cross-validation rules, value set checks
- Defaulting rules (AR AutoAccounting, OM defaulting, AP distribution sets)
- Security & row-level grants (HR security profile, FND menu/function checks)
- Workflow triggers (approval flows, events, business events)
- Subledger Accounting (SLA) event creation

Direct `INSERT INTO ap_invoices_all` bypasses all of that and corrupts the data model. Use the APIs.

## Files

| # | File | Package(s) covered | Verified call |
|---|---|---|---|
| 1 | [01_FND_Utilities.md](01_FND_Utilities.md)      | `fnd_global` · `fnd_profile` · `fnd_message` · `fnd_file` · `fnd_request` | `apps_initialize` + `profile.value` + `message.get` + `submit_request` |
| 2 | [02_HRMS_Employee.md](02_HRMS_Employee.md)      | `hr_employee_api` · `hr_person_api` · `hr_ex_employee_api` | `create_employee` — returns `person_id=32849 assignment_id=34073` |
| 3 | [03_AP_Supplier.md](03_AP_Supplier.md)          | `ap_vendor_pub_pkg` | `create_vendor` + `create_vendor_site` — returns `vendor_id=39179 site_id=8021` |
| 4 | [04_AR_Customer_TCA.md](04_AR_Customer_TCA.md)  | `hz_party_v2pub` · `hz_cust_account_v2pub` · `hz_location_v2pub` · `hz_party_site_v2pub` · `hz_cust_account_site_v2pub` | Full 6-step customer chain — returns `party_id=476204`, `cust_account_id=126871`, `site_use_id BILL_TO=14827` |
| 5 | [05_AR_Invoice_Receipt.md](05_AR_Invoice_Receipt.md) | `ar_invoice_api_pub` · `ar_receipt_api_pub` | `create_cash` — returns `cash_receipt_id=209296` |
| 6 | [06_INV_Item.md](06_INV_Item.md)                | `inv_item_grp` · `ego_item_pub` · `inv_txn_manager_pub` | `create_item` — returns `inventory_item_id=234206` |
| 7 | [07_OM_Order.md](07_OM_Order.md)                | `oe_order_pub` | `process_order` — returns `header_id=358767 order_number=69332` |
| 8 | [08_PO_Document_Control.md](08_PO_Document_Control.md) | `po_document_control_pub` | `control_document` reached API and returned functional validation |

## The universal call pattern

Every public API in this folder follows the same shape:

```sql
SET SERVEROUTPUT ON
DECLARE
  v_return_status VARCHAR2(10);
  v_msg_count     NUMBER;
  v_msg_data      VARCHAR2(4000);
BEGIN
  -- 1) context
  fnd_global.apps_initialize(<user_id>, <resp_id>, <resp_appl_id>);
  mo_global.set_policy_context('S', <org_id>);             -- for _ALL tables

  -- 2) the API call (record/table types populated before this)
  my_api_pkg.my_procedure(
      p_api_version   => 1.0,
      p_init_msg_list => fnd_api.g_true,
      p_commit        => fnd_api.g_false,
      x_return_status => v_return_status,
      x_msg_count     => v_msg_count,
      x_msg_data      => v_msg_data,
      ...);

  -- 3) always loop the error stack — x_msg_data only carries the first message
  IF v_return_status = fnd_api.g_ret_sts_success THEN
    COMMIT;
  ELSE
    FOR i IN 1..v_msg_count LOOP
      dbms_output.put_line(fnd_msg_pub.get(i, fnd_api.g_false));
    END LOOP;
    ROLLBACK;
  END IF;
END;
/
```

## Testing pattern: dry-run then rollback

Every sample in this folder uses `p_commit => fnd_api.g_false` + a final `ROLLBACK` so you can execute the call, see the real outputs and error stack, and leave no side effects. Once the call succeeds, flip `ROLLBACK` → `COMMIT`.

HR APIs use `p_validate => FALSE` (same effect, different parameter name).

## Before you call any of these in production

1. **Run it on your own instance first** — Oracle signatures drift across patches. Check `all_arguments` and adjust named parameters if they don't match.
2. **Read the error stack** — a single `x_msg_data` string only returns the first error. Loop `fnd_msg_pub.get(i, 'F')`.
3. **Set MOAC explicitly** — `fnd_global.apps_initialize` does NOT set `mo_global.set_policy_context` for you. OM needs both + `mo_global.init('ONT')`.
4. **Created_by_module** is required on every TCA record (HZ) — the API rejects the row silently if you omit it.

## Reference

- [Base_Tables/](../Base_Tables/) — the tables these APIs read/write.
- Oracle's Integration Repo (inside EBS): navigate to *Integrated SOA Gateway → Integration Repository*. Every public API is listed with its signature and full documentation.
- MOS doc IDs: 231283.1 (HR APIs), 1277505.1 (AR APIs), 433012.1 (OM), 1504702.1 (TCA).
