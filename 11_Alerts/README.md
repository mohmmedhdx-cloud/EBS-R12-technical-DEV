# 11 — Alerts

## What it is
**Oracle Alerts** are seeded framework jobs that run a SQL statement and, based on the rows returned, send notifications (email, concurrent program, PL/SQL) and/or update data. They're useful for monitoring (e.g. "any invoice on hold > 7 days?") without building a full concurrent program.

Two kinds:
- **Event Alert** — fires when a row is inserted/updated in a table, driven by a database trigger.
- **Periodic Alert** — fires on a schedule (minutes / hours / days).

## How to use
Responsibility **Alert Manager**:

1. **Alert → Define** — pick the application, give the alert a name.
2. Choose **Type** (Event / Periodic), enter the SQL *select*, and declare:
   - **Input columns** (bind variables `:SOMETHING`), and
   - **Output columns** (alias every selected column to a label — these become variables in actions).
3. **Actions** tab — define what to do with each returned row:
   - `Message` — an email (To/Cc/Subject/Body can reference `&OUTPUT_COL` variables).
   - `Concurrent Program` — submit one, passing output cols as arguments.
   - `SQL Statement Script` — run an update/insert.
   - `Operating Script` — run a shell script.
4. **Action Sets** — group actions; link them to the alert.
5. Test via **Request → Check** (periodic) or by inserting a triggering row (event).

## Sample — "Invoices on hold > 7 days" periodic alert

SQL:
```sql
SELECT  ai.invoice_num       AS inv_num,
        ai.invoice_amount    AS inv_amount,
        pv.vendor_name       AS supplier,
        ah.hold_reason       AS reason,
        TRUNC(SYSDATE - ah.hold_date) AS days_on_hold,
        fu.email_address     AS buyer_email
FROM    ap_invoices_all     ai,
        ap_holds_all        ah,
        po_vendors          pv,
        fnd_user            fu
WHERE   ai.invoice_id      = ah.invoice_id
AND     ah.release_lookup_code IS NULL
AND     ai.vendor_id       = pv.vendor_id
AND     ai.created_by      = fu.user_id
AND     TRUNC(SYSDATE - ah.hold_date) > 7
```

Output columns: `INV_NUM`, `INV_AMOUNT`, `SUPPLIER`, `REASON`, `DAYS_ON_HOLD`, `BUYER_EMAIL`.

Message action:
- **To** `&BUYER_EMAIL`
- **Subject** `Invoice &INV_NUM on hold &DAYS_ON_HOLD days`
- **Body**
  ```
  Supplier : &SUPPLIER
  Amount   : &INV_AMOUNT
  Reason   : &REASON
  Please review.
  ```

Schedule: frequency = *Every N days → 1*.

## Next commands
- Convert the same check into an **Event Alert** on `ap_holds_all` INSERT.
- Compare Alerts vs Workflow Business Events — when to pick which.
- Migrating an alert with FNDLOAD (`alr.lct`).
