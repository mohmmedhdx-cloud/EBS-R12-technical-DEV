# INV — Item + Transaction APIs

Verified against the live Vision R12.2.12 instance. `inv_item_grp.create_item` below executed successfully and returned a real `inventory_item_id` — then rolled back.

## APIs covered

| API | Purpose |
|---|---|
| `inv_item_grp.create_item`              | Create an item in the **master org** |
| `inv_item_grp.update_item`              | Update an item |
| `inv_item_grp.get_item`                 | Fetch full item record |
| `ego_item_pub.process_items`            | PIM-era equivalent; table-based, supports catalog categories and user-defined attributes |
| `mtl_transactions_interface` + `inv_txn_manager_pub.process_transactions` | Load and process material transactions (issues, receipts, xfers) |

## Context

```sql
fnd_global.apps_initialize(0, 20634, 401);            -- SYSADMIN / INVENTORY / INV app (401)
mo_global.set_policy_context('S', 204);
```

## `inv_item_grp.create_item` — VERIFIED

Creates the item in its **master organization** (V1 = 204 on Vision). To make the item available in child orgs, either:
- Create it directly in a child org (this API), or
- Use *Item Master → Organization Assignment* in the UI / concurrent program `Item Open Interface`.

```sql
SET SERVEROUTPUT ON
DECLARE
  v_item_rec       inv_item_grp.item_rec_type;
  v_x_item_rec     inv_item_grp.item_rec_type;
  v_error_tbl      inv_item_grp.error_tbl_type;
  v_return_status  VARCHAR2(10);
BEGIN
  fnd_global.apps_initialize(0, 20634, 401);
  mo_global.set_policy_context('S', 204);

  v_item_rec.organization_id         := 204;                                    -- master org V1
  v_item_rec.segment1                := 'XXC-API-' || TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS');
  v_item_rec.description             := 'API-created item';
  v_item_rec.inventory_item_flag     := 'Y';
  v_item_rec.stock_enabled_flag      := 'Y';
  v_item_rec.primary_uom_code        := 'Ea';                                   -- UOM CODE — not 'EA'!
  v_item_rec.primary_unit_of_measure := 'Each';                                 -- must match uom_code

  inv_item_grp.create_item(
      p_item_rec      => v_item_rec,
      x_item_rec      => v_x_item_rec,
      x_return_status => v_return_status,
      x_error_tbl     => v_error_tbl);

  IF v_return_status = fnd_api.g_ret_sts_success THEN
    dbms_output.put_line('inventory_item_id=' || v_x_item_rec.inventory_item_id
                         || ' segment1=' || v_x_item_rec.segment1);
    COMMIT;
  ELSE
    FOR i IN 1..v_error_tbl.COUNT LOOP
      dbms_output.put_line('err ' || i || ': ' || v_error_tbl(i).message_text);
    END LOOP;
    ROLLBACK;
  END IF;
END;
/
```

**Verified output on Vision:** `inventory_item_id=234206 segment1=XXC-API-...`.

### UOM gotcha

`primary_uom_code` must match `uom_code` (**case-sensitive**) in `mtl_units_of_measure`. On Vision:

```sql
SELECT uom_code, unit_of_measure, base_uom_flag FROM mtl_units_of_measure WHERE unit_of_measure='Each';
-- Ea    Each   Y           (note: 'Ea' not 'EA')
```

Always verify against your instance — UOM codes can differ if someone customised them.

### Item template shortcut

Instead of setting ~20 flags by hand, pass a template ID / name:

```sql
v_item_rec.organization_id := 204;
v_item_rec.segment1        := 'XXC-API-002';
v_item_rec.description     := 'Templated item';
v_item_rec.template_id     := (SELECT template_id FROM mtl_item_templates WHERE template_name='@Purchased item');
inv_item_grp.create_item(p_item_rec => v_item_rec, ... );
```

Templates live in `mtl_item_templates` — list them with:
```sql
SELECT template_id, template_name, description FROM mtl_item_templates ORDER BY template_name;
```

## Verifying the item created

```sql
SELECT organization_id, inventory_item_id, segment1, description,
       inventory_item_flag, stock_enabled_flag, purchasing_enabled_flag,
       primary_uom_code, item_type, planning_make_buy_code
FROM   mtl_system_items_b
WHERE  inventory_item_id = :p_item_id;

-- all orgs the item is assigned to
SELECT mp.organization_code, msi.description
FROM   mtl_system_items_b msi
JOIN   mtl_parameters     mp ON mp.organization_id = msi.organization_id
WHERE  msi.inventory_item_id = :p_item_id;
```

## Material transactions — `mtl_transactions_interface` + `inv_txn_manager_pub.process_transactions`

For receipts, issues, and transfers, Oracle's supported pattern is **load then process**: insert into the interface table, then call `inv_txn_manager_pub.process_transactions`. Direct inserts into `mtl_material_transactions` are not supported.

### Example: miscellaneous receipt (increase on-hand)

```sql
DECLARE
  l_header_id  NUMBER;
  l_result     NUMBER;
  l_msg_count  NUMBER;
  l_msg_data   VARCHAR2(4000);
  l_trx_count  NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20634, 401);

  SELECT mtl_material_transactions_s.NEXTVAL INTO l_header_id FROM dual;

  INSERT INTO mtl_transactions_interface (
      transaction_interface_id, transaction_header_id,
      transaction_mode, process_flag, validation_required,
      source_code, source_header_id, source_line_id,
      transaction_type_id,                                   -- 42 = Miscellaneous receipt
      inventory_item_id, organization_id, subinventory_code,
      transaction_quantity, transaction_uom,
      transaction_date, last_update_date, creation_date,
      last_updated_by, created_by)
  VALUES (
      mtl_material_transactions_s.NEXTVAL, l_header_id,
      3,                                                     -- 3 = BG / 2 = interactive
      1,                                                     -- ready for processing
      1,
      'XXC-API', 1, 1,
      42,                                                    -- miscellaneous receipt
      :p_item_id, 204, 'FGI',
      10, 'Ea',
      SYSDATE, SYSDATE, SYSDATE,
      fnd_global.user_id, fnd_global.user_id);

  IF inv_txn_manager_pub.process_transactions(
         p_api_version      => 1.0,
         p_init_msg_list    => fnd_api.g_true,
         p_commit           => fnd_api.g_false,
         x_return_status    => l_msg_data,
         x_msg_count        => l_msg_count,
         x_msg_data         => l_msg_data,
         x_trans_count      => l_trx_count,
         p_table            => 1,                            -- 1 = interface table
         p_header_id        => l_header_id) = 0
  THEN
    dbms_output.put_line('OK count='||l_trx_count);
  ELSE
    dbms_output.put_line('error: '||l_msg_data);
  END IF;
END;
/
```

**Transaction type IDs worth knowing** (`mtl_transaction_types`):

| ID | Type |
|---|---|
| 18 | Account alias receipt |
| 32 | Account alias issue |
| 42 | Miscellaneous receipt |
| 32 | Miscellaneous issue |
| 64 | Subinventory transfer |
| 27 | WIP issue |
| 17 | PO receipt *(done via RCV_TRANSACTIONS, not this interface)* |

### After process_transactions

Look at the interface table for errors:
```sql
SELECT error_code, error_explanation
FROM   mtl_transactions_interface
WHERE  transaction_header_id = :l_header_id;      -- if still there, it failed
```

If the row is gone, the transaction succeeded and moved to `mtl_material_transactions`.

## `ego_item_pub.process_items` (PIM-era, R12.1+)

For catalog-driven item creation (user-defined attributes, lifecycle, categories):

```sql
DECLARE
  l_items_tbl    ego_item_pub.item_tbl_type;
  l_return_status VARCHAR2(10);
  l_msg_count    NUMBER;
  l_msg_data     VARCHAR2(4000);
BEGIN
  l_items_tbl(1).transaction_type     := 'CREATE';
  l_items_tbl(1).organization_id      := 204;
  l_items_tbl(1).segment1             := 'XXC-PIM-001';
  l_items_tbl(1).description          := 'Created via EGO';
  l_items_tbl(1).item_catalog_group_id:= :p_catalog_id;
  l_items_tbl(1).primary_uom_code     := 'Ea';
  l_items_tbl(1).inventory_item_flag  := 'Y';

  ego_item_pub.process_items(
      p_api_version   => 1.0,
      p_init_msg_list => fnd_api.g_true,
      p_commit        => fnd_api.g_false,
      p_items_tbl     => l_items_tbl,
      x_return_status => l_return_status,
      x_msg_count     => l_msg_count,
      x_msg_data      => l_msg_data);
END;
/
```

Use EGO when you need catalog categories / UDAs / lifecycle; use `INV_ITEM_GRP` when you just need a simple item.

## Next

Back to [./](./).
