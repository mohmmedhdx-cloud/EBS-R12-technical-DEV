# AR — Invoice + Receipt APIs

Verified against the live Vision R12.2.12 instance. `ar_receipt_api_pub.create_cash` below executed successfully and returned a `cash_receipt_id` — then rolled back.

AR invoices and receipts each have their own public API. Both require a customer + site use (create those first — see [04_AR_Customer_TCA.md](./04_AR_Customer_TCA.md)).

## APIs covered

| API | Purpose |
|---|---|
| `ar_invoice_api_pub.create_single_invoice` | Create a single completed invoice (header + one line) |
| `ar_invoice_api_pub.create_invoice`        | Batch-mode — insert many invoices via `ar_invoice_api_pub.trx_header_tbl_type` / `trx_lines_tbl_type` |
| `ar_receipt_api_pub.create_cash`           | Create a cash receipt (optionally apply to an invoice) |
| `ar_receipt_api_pub.apply`                 | Apply an existing receipt to an invoice |
| `ar_receipt_api_pub.create_and_apply`      | Single call — create receipt + apply in one shot |
| `ar_receipt_api_pub.create_misc`           | Miscellaneous (non-invoice) receipt — interest, refunds, … |

## Context

```sql
fnd_global.apps_initialize(0, 20678, 222);
mo_global.set_policy_context('S', 204);
```

## `ar_receipt_api_pub.create_cash` — VERIFIED

```sql
SET SERVEROUTPUT ON
DECLARE
  v_return_status   VARCHAR2(10);
  v_msg_count       NUMBER;
  v_msg_data        VARCHAR2(4000);
  v_cash_receipt_id NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20678, 222);
  mo_global.set_policy_context('S', 204);

  ar_receipt_api_pub.create_cash(
      p_api_version          => 1.0,
      p_init_msg_list        => fnd_api.g_true,
      p_commit               => fnd_api.g_false,
      x_return_status        => v_return_status,
      x_msg_count            => v_msg_count,
      x_msg_data             => v_msg_data,
      p_currency_code        => 'USD',
      p_amount               => 100,
      p_receipt_number       => 'XXC-RCT-' || TO_CHAR(SYSTIMESTAMP,'YYMMDDHHMISSFF'),
      p_receipt_date         => DATE '2016-12-15',            -- an open AR period
      p_gl_date              => DATE '2016-12-15',
      p_customer_id          => 1004,                         -- Hilman and Associates (Vision)
      p_customer_site_use_id => 1017,                         -- their BILL_TO site
      p_receipt_method_id    => 1081,                         -- "Manual" method
      p_cr_id                => v_cash_receipt_id);

  dbms_output.put_line('status='||v_return_status||' cash_receipt_id='||v_cash_receipt_id);
  IF v_return_status <> 'S' THEN
    FOR i IN 1..v_msg_count LOOP
      dbms_output.put_line(fnd_msg_pub.get(i, fnd_api.g_false));
    END LOOP;
    ROLLBACK;
  ELSE
    COMMIT;
  END IF;
END;
/
```

**Verified output on Vision:** `status=S cash_receipt_id=209296`.

### Finding the right IDs on your instance

```sql
-- receipt methods available
SELECT receipt_method_id, name FROM ar_receipt_methods WHERE NVL(end_date,SYSDATE+1) > SYSDATE ORDER BY name;

-- open AR periods (must cover p_gl_date)
SELECT period_name, closing_status, start_date, end_date
FROM   gl_period_statuses
WHERE  ledger_id = 1 AND application_id = 222 AND closing_status IN ('O','F')
ORDER  BY start_date DESC;

-- customer + BILL_TO
SELECT ca.cust_account_id, ca.account_number, p.party_name, csu.site_use_id
FROM   hz_cust_accounts ca
JOIN   hz_parties p               ON p.party_id = ca.party_id
JOIN   hz_cust_acct_sites_all cas ON cas.cust_account_id = ca.cust_account_id AND cas.org_id = 204
JOIN   hz_cust_site_uses_all  csu ON csu.cust_acct_site_id = cas.cust_acct_site_id
                                 AND csu.site_use_code = 'BILL_TO' AND csu.status='A';
```

### "GL date not in an open or future-enterable period"

This is the most common error. `p_gl_date` **must** land in a period with `closing_status IN ('O','F')` for the **AR application_id=222** on the current ledger. Query `gl_period_statuses` above.

## `ar_receipt_api_pub.create_and_apply` — receipt + apply in one call

```sql
DECLARE
  v_return_status   VARCHAR2(10);
  v_msg_count       NUMBER;
  v_msg_data        VARCHAR2(4000);
  v_cash_receipt_id NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20678, 222);
  mo_global.set_policy_context('S', 204);

  ar_receipt_api_pub.create_and_apply(
      p_api_version          => 1.0,
      p_init_msg_list        => fnd_api.g_true,
      x_return_status        => v_return_status,
      x_msg_count            => v_msg_count,
      x_msg_data             => v_msg_data,
      p_currency_code        => 'USD',
      p_amount               => 500,
      p_receipt_number       => 'XXC-RCT-APP-' || TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS'),
      p_receipt_date         => TRUNC(SYSDATE),
      p_gl_date              => TRUNC(SYSDATE),
      p_customer_id          => :p_customer_id,
      p_customer_site_use_id => :p_site_use_id,
      p_receipt_method_id    => :p_receipt_method_id,
      p_customer_trx_id      => :p_invoice_id,              -- the invoice to apply to
      p_cr_id                => v_cash_receipt_id);
END;
/
```

## `ar_receipt_api_pub.apply` — apply existing receipt to invoice

```sql
DECLARE
  v_return_status  VARCHAR2(10);
  v_msg_count      NUMBER;
  v_msg_data       VARCHAR2(4000);
BEGIN
  fnd_global.apps_initialize(0, 20678, 222);
  mo_global.set_policy_context('S', 204);

  ar_receipt_api_pub.apply(
      p_api_version      => 1.0,
      p_init_msg_list    => fnd_api.g_true,
      x_return_status    => v_return_status,
      x_msg_count        => v_msg_count,
      x_msg_data         => v_msg_data,
      p_cash_receipt_id  => :p_cash_receipt_id,
      p_customer_trx_id  => :p_invoice_id,
      p_amount_applied   => 250,
      p_apply_date       => TRUNC(SYSDATE),
      p_apply_gl_date    => TRUNC(SYSDATE));
END;
/
```

## `ar_invoice_api_pub.create_invoice` — batch

Because the invoice API takes **table-of-records** for header / lines / distributions / sales credits, the typical pattern is:

```sql
DECLARE
  l_batch_source_rec ar_invoice_api_pub.batch_source_rec_type;
  l_trx_header_tbl   ar_invoice_api_pub.trx_header_tbl_type;
  l_trx_lines_tbl    ar_invoice_api_pub.trx_line_tbl_type;
  l_trx_dist_tbl     ar_invoice_api_pub.trx_dist_tbl_type;
  l_trx_salescredits_tbl ar_invoice_api_pub.trx_salescredits_tbl_type;

  v_return_status    VARCHAR2(10);
  v_msg_count        NUMBER;
  v_msg_data         VARCHAR2(4000);
  v_customer_trx_id  NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20678, 222);
  mo_global.set_policy_context('S', 204);

  l_batch_source_rec.batch_source_id := -1;                  -- Manual
  -- or: l_batch_source_rec.batch_source_name := 'Manual';

  -- HEADER
  l_trx_header_tbl(1).trx_header_id       := 1;              -- correlation id across tbl types
  l_trx_header_tbl(1).trx_date            := TRUNC(SYSDATE);
  l_trx_header_tbl(1).trx_currency        := 'USD';
  l_trx_header_tbl(1).trx_class           := 'INV';          -- INV / CM / DM
  l_trx_header_tbl(1).cust_trx_type_id    := 1;              -- "Invoice"
  l_trx_header_tbl(1).bill_to_customer_id := :p_customer_id;
  l_trx_header_tbl(1).bill_to_site_use_id := :p_site_use_id;
  l_trx_header_tbl(1).term_id             := :p_term_id;
  l_trx_header_tbl(1).gl_date             := TRUNC(SYSDATE);
  l_trx_header_tbl(1).comments            := 'XXC API invoice';

  -- LINE
  l_trx_lines_tbl(1).trx_header_id      := 1;                -- matches header corr id
  l_trx_lines_tbl(1).trx_line_id        := 1;
  l_trx_lines_tbl(1).line_number        := 1;
  l_trx_lines_tbl(1).line_type          := 'LINE';
  l_trx_lines_tbl(1).description        := 'XXC API line';
  l_trx_lines_tbl(1).quantity_invoiced  := 1;
  l_trx_lines_tbl(1).unit_selling_price := 100;
  l_trx_lines_tbl(1).inventory_item_id  := :p_item_id;

  -- (distributions + salescredits optional — AR will auto-gen from AutoAccounting)

  ar_invoice_api_pub.create_invoice(
      p_api_version          => 1.0,
      p_init_msg_list        => fnd_api.g_true,
      p_commit               => fnd_api.g_false,
      p_batch_source_rec     => l_batch_source_rec,
      p_trx_header_tbl       => l_trx_header_tbl,
      p_trx_lines_tbl        => l_trx_lines_tbl,
      p_trx_dist_tbl         => l_trx_dist_tbl,
      p_trx_salescredits_tbl => l_trx_salescredits_tbl,
      x_customer_trx_id      => v_customer_trx_id,
      x_return_status        => v_return_status,
      x_msg_count            => v_msg_count,
      x_msg_data             => v_msg_data);
END;
/
```

### Picking the right batch source

```sql
SELECT batch_source_id, name, batch_source_type
FROM   ra_batch_sources_all
WHERE  org_id = 204 AND status='A'
AND    batch_source_type='INV'
ORDER  BY batch_source_id;
```

Use `-1` / `Manual` to let AR assign the transaction number automatically. With a custom batch source, you can pass `trx_number` explicitly but must respect its auto-numbering rule.

## Verification queries

```sql
-- invoice headers created recently in this OU
SELECT customer_trx_id, trx_number, trx_date, status_trx, complete_flag, bill_to_customer_id
FROM   ra_customer_trx_all
WHERE  org_id = 204 AND creation_date > SYSDATE - 1
ORDER  BY creation_date DESC;

-- invoice lines
SELECT trl.line_number, trl.description, trl.quantity_invoiced, trl.unit_selling_price, trl.extended_amount
FROM   ra_customer_trx_lines_all trl
WHERE  trl.customer_trx_id = :p_customer_trx_id
ORDER  BY trl.line_number;

-- receipts
SELECT cash_receipt_id, receipt_number, amount, currency_code, status, pay_from_customer
FROM   ar_cash_receipts_all
WHERE  org_id = 204 AND creation_date > SYSDATE - 1
ORDER  BY creation_date DESC;

-- applications (links a receipt to an invoice)
SELECT receivable_application_id, status, amount_applied, applied_customer_trx_id, cash_receipt_id
FROM   ar_receivable_applications_all
WHERE  cash_receipt_id = :p_cash_receipt_id;
```

## Gotchas

- **`trx_header_id`** in the `_tbl` types is your *own* correlation ID — it ties header row `1` to line rows with the same `1`. It is **not** the real customer_trx_id (that comes back as `x_customer_trx_id`).
- AR periods must be open for **application_id=222** specifically — the GL and AP period statuses are independent.
- `p_validate` is not a parameter on AR APIs (unlike HR). Use `p_commit => fnd_api.g_false` for dry-run-with-rollback.
- `create_cash` supports `p_customer_number` **or** `p_customer_id`; if both are passed, the ID wins.
- `ar_receipt_api_pub.create_cash` + `apply` is two separate autonomous commits — prefer `create_and_apply` if you want atomicity.

## Next

Back to [./](./).
