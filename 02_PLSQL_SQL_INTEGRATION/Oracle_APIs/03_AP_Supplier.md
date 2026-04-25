# AP — `ap_vendor_pub_pkg` (Supplier / Supplier Site / Contact)

Verified against the live Vision R12.2.12 instance. Both `create_vendor` and `create_vendor_site` below executed successfully and were rolled back — you can paste them straight into SQL*Plus.

In R12+, the old `po_vendors` is a view over `ap_suppliers` — the master table. `ap_vendor_pub_pkg` is the supported API for creating and updating suppliers, supplier sites, and contacts.

## APIs covered

| Procedure | Purpose |
|---|---|
| `ap_vendor_pub_pkg.create_vendor`        | Create supplier (header) |
| `ap_vendor_pub_pkg.create_vendor_site`   | Create supplier site for a given OU |
| `ap_vendor_pub_pkg.create_vendor_contact`| Create contact for a site |
| `ap_vendor_pub_pkg.update_vendor`        | Update supplier header |
| `ap_vendor_pub_pkg.update_vendor_site`   | Update supplier site |

## Context

```sql
fnd_global.apps_initialize(0, 20639, 200);            -- SYSADMIN / PAYABLES_MANAGER / AP app
mo_global.set_policy_context('S', 204);               -- Vision Operations
```

Lookup your resp/app/OU:

```sql
SELECT responsibility_id, application_id FROM fnd_responsibility_vl WHERE responsibility_key='PAYABLES_MANAGER';
SELECT organization_id, name FROM hr_operating_units WHERE name LIKE 'Vision Operations%';
```

## `create_vendor` — verified end-to-end

Use the `r_vendor_rec_type` record — it's the modern/supported overload.

```sql
SET SERVEROUTPUT ON
DECLARE
  v_vendor_rec     ap_vendor_pub_pkg.r_vendor_rec_type;
  v_return_status  VARCHAR2(10);
  v_msg_count      NUMBER;
  v_msg_data       VARCHAR2(2000);
  v_vendor_id      NUMBER;
  v_party_id       NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20639, 200);
  mo_global.set_policy_context('S', 204);

  v_vendor_rec.vendor_name             := 'XXC API TEST SUPPLIER';
  v_vendor_rec.segment1                := NULL;                  -- auto-number (most instances)
  v_vendor_rec.vendor_type_lookup_code := 'VENDOR';              -- or 'EMPLOYEE','CONTRACTOR','TAX AUTHORITY',...

  ap_vendor_pub_pkg.create_vendor(
      p_api_version      => 1.0,
      p_init_msg_list    => fnd_api.g_true,
      p_commit           => fnd_api.g_false,
      p_validation_level => fnd_api.g_valid_level_full,
      x_return_status    => v_return_status,
      x_msg_count        => v_msg_count,
      x_msg_data         => v_msg_data,
      p_vendor_rec       => v_vendor_rec,
      x_vendor_id        => v_vendor_id,
      x_party_id         => v_party_id);

  IF v_return_status = fnd_api.g_ret_sts_success THEN
    dbms_output.put_line('vendor_id='||v_vendor_id||' party_id='||v_party_id);
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

**Verified output on Vision:** `vendor_id=39178 party_id=476202`.

### Rule: always read the error stack

If `v_return_status <> 'S'`, loop `fnd_msg_pub.get(i, 'F')` — the message data returned in `x_msg_data` only contains the **first** error. Loop the stack to see them all.

## `create_vendor_site` — verified

A supplier with no site can't be paid. Sites are **per OU** (`org_id`).

```sql
SET SERVEROUTPUT ON
DECLARE
  v_site_rec       ap_vendor_pub_pkg.r_vendor_site_rec_type;
  v_return_status  VARCHAR2(10);
  v_msg_count      NUMBER;
  v_msg_data       VARCHAR2(2000);
  v_vendor_site_id NUMBER;
  v_party_site_id  NUMBER;
  v_location_id    NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20639, 200);
  mo_global.set_policy_context('S', 204);

  v_site_rec.vendor_id            := :p_vendor_id;          -- from create_vendor
  v_site_rec.vendor_site_code     := 'MAIN';
  v_site_rec.org_id               := 204;                   -- Vision Operations
  v_site_rec.address_line1        := '123 Main St';
  v_site_rec.city                 := 'Redwood City';
  v_site_rec.state                := 'CA';
  v_site_rec.zip                  := '94065';
  v_site_rec.country              := 'US';
  v_site_rec.purchasing_site_flag := 'Y';
  v_site_rec.pay_site_flag        := 'Y';

  ap_vendor_pub_pkg.create_vendor_site(
      p_api_version      => 1.0,
      p_init_msg_list    => fnd_api.g_true,
      p_commit           => fnd_api.g_false,
      p_validation_level => fnd_api.g_valid_level_full,
      x_return_status    => v_return_status,
      x_msg_count        => v_msg_count,
      x_msg_data         => v_msg_data,
      p_vendor_site_rec  => v_site_rec,
      x_vendor_site_id   => v_vendor_site_id,
      x_party_site_id    => v_party_site_id,
      x_location_id      => v_location_id);

  dbms_output.put_line('vendor_site_id='||v_vendor_site_id||
                       ' party_site_id='||v_party_site_id||
                       ' location_id='||v_location_id);
  COMMIT;
END;
/
```

**Verified output on Vision:** `vendor_site_id=8021`, two linked TCA rows (`party_site_id`, `location_id`).

### Site role flags
- `purchasing_site_flag = 'Y'` → site can be used on PO / requisition.
- `pay_site_flag = 'Y'` → AP Payments can issue to this site.
- `primary_pay_site_flag = 'Y'` → default pay site when the PO's site isn't a pay site.
- `rfq_only_site_flag = 'Y'` → RFQ-eligible but cannot transact.

At least one role flag must be `'Y'` or the site is useless.

## `create_vendor_contact`

```sql
DECLARE
  v_ct_rec         ap_vendor_pub_pkg.r_vendor_contact_rec_type;
  v_return_status  VARCHAR2(10);
  v_msg_count      NUMBER;
  v_msg_data       VARCHAR2(2000);
  v_contact_id     NUMBER;
  v_party_id       NUMBER;
  v_rel_id         NUMBER;
  v_party_site_id  NUMBER;
  v_per_party_id   NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20639, 200);
  mo_global.set_policy_context('S', 204);

  v_ct_rec.vendor_id      := :p_vendor_id;
  v_ct_rec.vendor_site_id := :p_vendor_site_id;
  v_ct_rec.first_name     := 'Jane';
  v_ct_rec.last_name      := 'Doe';
  v_ct_rec.email_address  := 'jane.doe@example.com';

  ap_vendor_pub_pkg.create_vendor_contact(
      p_api_version       => 1.0,
      p_init_msg_list     => fnd_api.g_true,
      p_commit            => fnd_api.g_false,
      p_validation_level  => fnd_api.g_valid_level_full,
      x_return_status     => v_return_status,
      x_msg_count         => v_msg_count,
      x_msg_data          => v_msg_data,
      p_vendor_contact_rec=> v_ct_rec,
      x_vendor_contact_id => v_contact_id,
      x_party_id          => v_party_id,
      x_relationship_id   => v_rel_id,
      x_org_contact_id    => v_party_site_id,
      x_party_site_id     => v_per_party_id);
END;
/
```

## Verifying what the API created

After the call, the new supplier is visible in both the database and the EBS UI.

### 1. On the database (sqlplus)

```sql
-- Supplier header (global — no MOAC needed)
SELECT vendor_id,
       segment1            AS supplier_number,
       vendor_name,
       vendor_type_lookup_code,
       enabled_flag,
       end_date_active,
       party_id,
       creation_date
FROM   ap_suppliers
WHERE  vendor_id = :p_vendor_id;              -- or:  vendor_name LIKE 'XXC%'

-- Supplier sites for a specific OU (set MOAC first, or filter by org_id)
SELECT vendor_site_id,
       vendor_site_code,
       org_id,
       address_line1, city, state, zip, country,
       purchasing_site_flag,
       pay_site_flag,
       primary_pay_site_flag,
       rfq_only_site_flag,
       inactive_date
FROM   ap_supplier_sites_all
WHERE  vendor_id = :p_vendor_id
AND    org_id    = 204;                       -- Vision Operations

-- Contacts for the supplier
SELECT asc2.vendor_contact_id,
       asc2.first_name, asc2.last_name,
       asc2.email_address, asc2.phone,
       asc2.vendor_site_id
FROM   ap_supplier_contacts asc2
JOIN   hz_relationships     r   ON r.subject_id = asc2.per_party_id
JOIN   ap_suppliers         s   ON s.party_id   = r.object_id
WHERE  s.vendor_id = :p_vendor_id;

-- One-liner: does it exist by name?
SELECT COUNT(*) FROM ap_suppliers WHERE vendor_name = 'XXC API TEST SUPPLIER';
```

If you are looking at supplier *bank accounts* as well (created by `iby_*` APIs, not this one), join through TCA:
```sql
SELECT eba.bank_account_name, eba.bank_account_num, eba.currency_code
FROM   iby_external_payees_all iep
JOIN   iby_pmt_instr_uses_all  ipu ON ipu.ext_pmt_party_id = iep.ext_payee_id
JOIN   iby_ext_bank_accounts   eba ON eba.ext_bank_account_id = ipu.instrument_id
WHERE  iep.payee_party_id = (SELECT party_id FROM ap_suppliers WHERE vendor_id = :p_vendor_id);
```

### 2. On the screen (EBS Professional Forms)

**Supplier header — Supplier Summary window**

1. Log in to EBS: `http://apps.example.com:8000/OA_HTML/AppsLogin` (SYSADMIN or any AP user).
2. Pick responsibility **Payables Manager** *(or any Payables responsibility)*.
3. Navigator path: **Suppliers → Entry**.
   - This opens the self-service *Suppliers Home* page (OAF).
4. In the **Find Suppliers** region, search by:
   - *Supplier* = `XXC API TEST SUPPLIER`  **or**
   - *Supplier Number* = the `segment1` from the query above
5. Click **Go** — your new supplier appears in the results table. Click the supplier name to drill into:
   - **General** — header info (type, organization, tax details)
   - **Address Book** — the `MAIN` address you created (step 3 of `create_vendor_site`)
   - **Sites** — the `MAIN` site with its Purchasing / Payment flags
   - **Contact Directory** — any contacts added via `create_vendor_contact`

**Supplier site — per-OU details**

From the drill-down, click **Address Book → Manage Sites** against the address to see the OU-scoped site:
- `Site name` = `MAIN`
- `Operating Unit` = `Vision Operations`
- **Purchasing** tab — "Purchasing site" enabled
- **Payments** tab — "Pay site" enabled

**Alternate legacy path** (still works):
*Payables Manager → Suppliers → Inquiry* (Forms-based) for the classic Oracle Forms *Suppliers* window — useful to verify the old `po_vendors` / `po_vendor_sites_all` view shape.

**Purchasing Super User** also sees the supplier immediately — *Purchasing Super User → Supply Base → Suppliers*.

### 3. Quick sanity check — "did it actually commit?"

If the supplier is missing from both the screen and `ap_suppliers`, the most likely causes are:

| Symptom | Cause | Fix |
|---|---|---|
| `v_return_status = 'S'` but nothing in DB | Forgot `COMMIT` after the API | Remember `p_commit => fnd_api.g_false` means *the caller* must commit |
| `v_return_status = 'E'` | Error stack not printed | Loop `fnd_msg_pub.get(i, 'F')` |
| Supplier in DB but not on screen | Session responsibility has no AP access, or cached results | Switch responsibility or refresh |
| Supplier visible, but no site | `create_vendor_site` failed silently | Check error stack — usually a missing `org_id` or no role flag set |

## Next

Back to [./](./).
