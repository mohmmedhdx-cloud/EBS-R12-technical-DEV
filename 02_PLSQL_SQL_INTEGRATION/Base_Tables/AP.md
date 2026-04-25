# AP — Payables Base Tables & Joins (SQL & PL/SQL for EBS)

All tables below **verified against the live Vision R12.2.12 instance** (`apps/apps@EBSDB`).

Any table ending `_ALL` carries an `ORG_ID` column — you **must** set the MOAC context before querying, or the query returns zero rows:

```sql
EXEC mo_global.set_policy_context('S', 204);     -- Vision Operations OU
```

(Or initialize the full apps session: `EXEC fnd_global.apps_initialize(1318, 50855, 200);` for AP Manager.)

## Tables

| Table | ORG_ID | Purpose |
|---|---|---|
| `AP_INVOICES_ALL` | ✅ | Invoice headers (one row per invoice) |
| `AP_INVOICE_LINES_ALL` | ✅ | Invoice lines (R12+ structure between header and distributions) |
| `AP_INVOICE_DISTRIBUTIONS_ALL` | ✅ | Distribution rows (accounting detail per line) |
| `AP_INVOICE_PAYMENTS_ALL` | ✅ | Links invoices to payments |
| `AP_PAYMENT_SCHEDULES_ALL` | ✅ | Due-date schedules for invoices (installments) |
| `AP_CHECKS_ALL` | ✅ | Payment documents (checks / EFT / wire) |
| `AP_HOLDS_ALL` | ✅ | Current and historical invoice holds |
| `AP_HOLD_CODES` | — | Hold reason master |
| `AP_SUPPLIERS` | — | Supplier header (TCA party + AP-specific attrs) |
| `AP_SUPPLIER_SITES_ALL` | ✅ | Supplier sites (one row per supplier × OU × location) |
| `AP_SUPPLIER_CONTACTS` | — | Supplier contacts |
| `AP_TERMS` | — | Payment terms (synonym over AP.AP_TERMS_TL) |
| `AP_TERMS_LINES` | — | Discount / due-date components of a term |
| `AP_BANK_ACCOUNT_USES_ALL` | ✅ | OU-level uses of bank accounts |
| `AP_BANK_ACCOUNTS_ALL` | ✅ | *(legacy R12 structure — new accounts live in `CE_BANK_ACCOUNTS`)* |
| `AP_BANK_BRANCHES` | — | Bank branches master |
| `CE_BANK_ACCOUNTS` | — | Cash Management bank accounts (R12 replaces the old AP store) |
| `CE_BANKS_V` | — | View over TCA organizations classified as Bank |
| `IBY_EXT_BANK_ACCOUNTS` | — | External bank accounts (Payments module, used for supplier EFT) |
| `AP_SYSTEM_PARAMETERS_ALL` | ✅ | Per-OU Payables setup (default accounts, controls) |
| `AP_PAYMENT_HISTORY_ALL` | ✅ | History of payment events (created, voided, cleared) |
| `AP_ACCOUNTING_EVENTS_ALL` | ✅ | Accounting events feeding SLA (Subledger Accounting) |
| `AP_AE_HEADERS_ALL` | ✅ | AP-originated accounting entry headers |
| `AP_AE_LINES_ALL` | ✅ | AP-originated accounting entry lines |
| `AP_INVOICES_INTERFACE` | ✅ | Open Interface inbound invoice headers |
| `AP_INVOICE_LINES_INTERFACE` | ✅ | Open Interface inbound invoice lines |
| `PO_VENDORS` | — | R12 **view** over `AP_SUPPLIERS` (kept for backward compatibility) |
| `PO_VENDOR_SITES_ALL` | ✅ | R12 **view** over `AP_SUPPLIER_SITES_ALL` |

## Canonical joins (all verified)

### Invoice → Lines → Distributions

```sql
SELECT inv.invoice_num,
       inv.invoice_date,
       lin.line_number,
       lin.description,
       dist.distribution_line_number,
       dist.dist_code_combination_id,
       dist.amount
FROM   ap_invoices_all               inv
JOIN   ap_invoice_lines_all          lin  ON lin.invoice_id  = inv.invoice_id
JOIN   ap_invoice_distributions_all  dist ON dist.invoice_id = inv.invoice_id
                                         AND dist.invoice_line_number = lin.line_number
WHERE  inv.org_id = 204
ORDER  BY inv.invoice_num, lin.line_number, dist.distribution_line_number;
```

### Invoice → Supplier → Supplier site → Terms

```sql
SELECT inv.invoice_num,
       s.vendor_name,
       ss.vendor_site_code,
       t.name           AS term_name,
       inv.invoice_amount
FROM   ap_invoices_all        inv
JOIN   ap_suppliers           s  ON s.vendor_id  = inv.vendor_id
JOIN   ap_supplier_sites_all  ss ON ss.vendor_site_id = inv.vendor_site_id
LEFT JOIN ap_terms            t  ON t.term_id    = inv.terms_id
WHERE  inv.org_id = 204;
```

### Invoice → Payment schedules → Payments → Checks

```sql
SELECT inv.invoice_num,
       ps.payment_num,
       ps.due_date,
       ps.amount_remaining,
       ip.amount               AS paid_amount,
       ck.check_number,
       ck.amount               AS check_amount,
       ck.status_lookup_code   AS check_status
FROM   ap_invoices_all            inv
JOIN   ap_payment_schedules_all   ps  ON ps.invoice_id = inv.invoice_id
LEFT JOIN ap_invoice_payments_all ip  ON ip.invoice_id = inv.invoice_id
LEFT JOIN ap_checks_all           ck  ON ck.check_id   = ip.check_id
WHERE  inv.org_id = 204;
```

### Invoice → Current holds → Hold reason

```sql
SELECT inv.invoice_num,
       h.hold_lookup_code,
       hc.description        AS hold_reason,
       h.hold_date,
       h.release_lookup_code
FROM   ap_invoices_all inv
JOIN   ap_holds_all    h    ON h.invoice_id        = inv.invoice_id
JOIN   ap_hold_codes   hc   ON hc.hold_lookup_code = h.hold_lookup_code
WHERE  h.release_lookup_code IS NULL                   -- only open holds
AND    inv.org_id = 204;
```

### Invoice accounting (SLA)

```sql
SELECT inv.invoice_num,
       evt.accounting_event_id,
       hdr.ae_header_id,
       lin.ae_line_number,
       lin.code_combination_id,
       lin.accounted_dr,
       lin.accounted_cr
FROM   ap_invoices_all            inv
JOIN   ap_accounting_events_all   evt ON evt.source_id = inv.invoice_id
                                      AND evt.source_table = 'AP_INVOICES'
JOIN   ap_ae_headers_all          hdr ON hdr.accounting_event_id = evt.accounting_event_id
JOIN   ap_ae_lines_all            lin ON lin.ae_header_id = hdr.ae_header_id
WHERE  inv.org_id = 204;
```

### Supplier → Sites → Bank account (EFT)

```sql
SELECT s.vendor_name,
       ss.vendor_site_code,
       eba.bank_account_name,
       eba.bank_account_num,
       eba.iban,
       eba.currency_code
FROM   ap_suppliers                   s
JOIN   ap_supplier_sites_all          ss  ON ss.vendor_id = s.vendor_id
JOIN   iby_external_payees_all        pe  ON pe.payee_party_id = s.party_id
                                         AND pe.party_site_id  = ss.party_site_id
JOIN   iby_pmt_instr_uses_all         iu  ON iu.ext_pmt_party_id = pe.ext_payee_id
JOIN   iby_ext_bank_accounts          eba ON eba.ext_bank_account_id = iu.instrument_id
WHERE  iu.instrument_type = 'BANKACCOUNT'
AND    ss.org_id = 204;
```

## Open Interface ingestion (AP_INVOICES_INTERFACE)

Load rows into `AP_INVOICES_INTERFACE` + `AP_INVOICE_LINES_INTERFACE`, then submit the seeded program *Payables Open Interface Import* (short name `APXIIMPT`).

Both interface tables have `ORG_ID`, so MOAC must be set before inserting (or supply `ORG_ID` explicitly in each row).

## Next

Back to [../Base_Tables/](../Base_Tables/) · See also [../Oracle_APIs/AP/](../Oracle_APIs/AP/) for supplier create/update scripts.
