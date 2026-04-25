# AR — Receivables Base Tables & Joins (SQL & PL/SQL for EBS)

Verified against the live Vision R12.2.12 instance. **Customer data lives in the Trading Community Architecture (TCA)** — the `HZ_*` tables — and AR adds transactional tables on top (invoices, receipts, adjustments).

All `_ALL` tables carry `ORG_ID`. Set MOAC before querying:

```sql
EXEC mo_global.set_policy_context('S', 204);
```

## TCA (Customer-master) tables

| Table | ORG_ID | Purpose |
|---|---|---|
| `HZ_PARTIES` | — | The canonical party (org / person / group). Global — no OU |
| `HZ_PARTY_SITES` | — | Addresses associated with a party |
| `HZ_LOCATIONS` | — | Physical address detail (country, city, postal code) |
| `HZ_ORG_CONTACTS` | — | Contact persons linked to an organization party |
| `HZ_RELATIONSHIPS` | — | Party-to-party relationships (contact, parent, …) |
| `HZ_PERSON_PROFILES` | — | Person-party attributes |
| `HZ_CONTACT_POINTS` | — | Phones, emails, URLs, EDI endpoints |
| `HZ_CUST_ACCOUNTS` | has col, **global in practice** | Customer account (one party can have many accounts) |
| `HZ_CUST_ACCT_SITES_ALL` | ✅ | Customer account × site (linked to party site) |
| `HZ_CUST_SITE_USES_ALL` | ✅ | Site use (`BILL_TO`, `SHIP_TO`, `STMTS`, …) |
| `HZ_CUSTOMER_PROFILES` | — | Credit / dunning / receipt method profile for a customer account |

## Transactional (invoices, receipts) tables

| Table | ORG_ID | Purpose |
|---|---|---|
| `RA_CUSTOMER_TRX_ALL` | ✅ | Transaction headers (INV / CM / DM / DEP / GUA) |
| `RA_CUSTOMER_TRX_LINES_ALL` | ✅ | Transaction lines (LINE / TAX / CHARGES / FREIGHT) |
| `RA_CUST_TRX_LINE_GL_DIST_ALL` | ✅ | GL distributions per line |
| `RA_CUST_TRX_TYPES_ALL` | ✅ | Transaction type master |
| `AR_PAYMENT_SCHEDULES_ALL` | ✅ | Balance + aging rows (one per trx or receipt) |
| `RA_BATCHES_ALL` | ✅ | Invoice/transaction batches |
| `RA_INTERFACE_LINES_ALL` | ✅ | AutoInvoice open interface |
| `RA_INTERFACE_DISTRIBUTIONS_ALL` | ✅ | AutoInvoice distribution interface |
| `AR_CASH_RECEIPTS_ALL` | ✅ | Receipt headers |
| `AR_RECEIVABLE_APPLICATIONS_ALL` | ✅ | Receipt applications (CASH / CM / ON_ACCOUNT / UNAPP) |
| `AR_ADJUSTMENTS_ALL` | ✅ | Invoice adjustments |
| `AR_RECEIVABLES_TRX_ALL` | ✅ | Receivables activity master (write-off, adjustment, …) |
| `AR_SYSTEM_PARAMETERS_ALL` | ✅ | Per-OU AR setup |
| `AR_MEMO_LINES_ALL_B` | ✅ | Standard memo lines master |
| `AR_MEMO_LINES_ALL_TL` | ✅ | Translated memo-line names |
| `AP_TERMS` | — | Payment terms (shared with AP — R12 consolidated them) |
| `AR_CUSTOMERS` | — | **R12 view** over `HZ_PARTIES + HZ_CUST_ACCOUNTS` (backward compat) |

## Canonical joins (all verified)

### Party → Customer Account → Account Site → Site Use

```sql
SELECT p.party_name,
       ca.account_number,
       ca.account_name,
       loc.country, loc.city,
       csu.site_use_code,
       csu.location        AS site_label
FROM   hz_parties              p
JOIN   hz_cust_accounts        ca  ON ca.party_id          = p.party_id
JOIN   hz_cust_acct_sites_all  cas ON cas.cust_account_id  = ca.cust_account_id
JOIN   hz_cust_site_uses_all   csu ON csu.cust_acct_site_id = cas.cust_acct_site_id
JOIN   hz_party_sites          ps  ON ps.party_site_id     = cas.party_site_id
JOIN   hz_locations            loc ON loc.location_id      = ps.location_id
WHERE  cas.org_id = 204
AND    csu.status = 'A'
AND    ca.status  = 'A';
```

### Invoice → Lines → GL Distributions

```sql
SELECT t.trx_number,
       t.trx_date,
       l.line_number,
       l.line_type,
       l.description,
       l.extended_amount,
       g.code_combination_id,
       g.amount
FROM   ra_customer_trx_all          t
JOIN   ra_customer_trx_lines_all    l ON l.customer_trx_id      = t.customer_trx_id
JOIN   ra_cust_trx_line_gl_dist_all g ON g.customer_trx_line_id = l.customer_trx_line_id
WHERE  t.org_id        = 204
AND    t.complete_flag = 'Y'
ORDER  BY t.trx_number, l.line_number;
```

### Invoice → Customer + Bill-to site

```sql
SELECT t.trx_number,
       t.trx_date,
       p.party_name,
       ca.account_number,
       loc.city || ', ' || loc.country AS bill_to,
       tt.name            AS transaction_type,
       apst.due_date
FROM   ra_customer_trx_all       t
JOIN   ra_cust_trx_types_all     tt   ON tt.cust_trx_type_id = t.cust_trx_type_id
JOIN   hz_cust_accounts          ca   ON ca.cust_account_id  = t.bill_to_customer_id
JOIN   hz_parties                p    ON p.party_id          = ca.party_id
JOIN   hz_cust_site_uses_all     csu  ON csu.site_use_id     = t.bill_to_site_use_id
JOIN   hz_cust_acct_sites_all    cas  ON cas.cust_acct_site_id = csu.cust_acct_site_id
JOIN   hz_party_sites            ps   ON ps.party_site_id    = cas.party_site_id
JOIN   hz_locations              loc  ON loc.location_id     = ps.location_id
JOIN   ar_payment_schedules_all  apst ON apst.customer_trx_id = t.customer_trx_id
WHERE  t.org_id = 204;
```

### Open receivables (unpaid invoices)

```sql
SELECT ps.trx_number,
       ps.due_date,
       ps.amount_due_original,
       ps.amount_due_remaining,
       TRUNC(SYSDATE - ps.due_date) AS days_overdue,
       p.party_name
FROM   ar_payment_schedules_all  ps
JOIN   hz_cust_accounts          ca ON ca.cust_account_id = ps.customer_id
JOIN   hz_parties                p  ON p.party_id         = ca.party_id
WHERE  ps.status              = 'OP'                      -- open
AND    ps.amount_due_remaining > 0
AND    ps.org_id              = 204
ORDER  BY days_overdue DESC;
```

### Receipts → Applications

```sql
SELECT r.receipt_number,
       r.receipt_date,
       r.amount             AS receipt_amount,
       ra.status            AS app_status,         -- APP / UNAPP / ACC / OTHER_ACC
       ra.amount_applied,
       ra.applied_customer_trx_id,
       t.trx_number         AS applied_to_invoice
FROM   ar_cash_receipts_all          r
JOIN   ar_receivable_applications_all ra ON ra.cash_receipt_id = r.cash_receipt_id
LEFT JOIN ra_customer_trx_all         t  ON t.customer_trx_id  = ra.applied_customer_trx_id
WHERE  r.org_id = 204;
```

### Adjustments

```sql
SELECT adj.adjustment_number,
       adj.apply_date,
       adj.amount,
       adj.reason_code,
       rt.name              AS receivables_activity,
       t.trx_number         AS invoice
FROM   ar_adjustments_all        adj
JOIN   ra_customer_trx_all       t  ON t.customer_trx_id = adj.customer_trx_id
JOIN   ar_receivables_trx_all    rt ON rt.receivables_trx_id = adj.receivables_trx_id
WHERE  adj.org_id = 204;
```

## TCA pitfalls

- `HZ_PARTIES.STATUS = 'A'` and `HZ_CUST_ACCOUNTS.STATUS = 'A'` — both must be *Active* to be a valid receivable customer.
- A party may have **multiple customer accounts** (common for corporate/subsidiary setups) — filter by `HZ_CUST_ACCOUNTS.CUSTOMER_TYPE` if needed.
- The **party relationship** (`HZ_RELATIONSHIPS`) is how you model parent/child, bill-to vs ship-to contacts, and contact persons.
- Addresses have three levels: **party site → location** (global) and **customer account site** (OU-specific). Don't mix them.

## Next

Back to [../Base_Tables/](../Base_Tables/) · See also [../Oracle_APIs/AR/](../Oracle_APIs/AR/) for TCA create/update scripts.
