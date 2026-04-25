# INV — Inventory Base Tables & Joins (SQL & PL/SQL for EBS)

Verified against the live Vision R12.2.12 instance.

INV is partitioned by **`ORGANIZATION_ID`** (inventory organization), **not** `ORG_ID`. Most queries need to filter by organization. The closest thing to MOAC is the **inventory-org** context, set with:

```sql
EXEC mo_global.init('INV');             -- optional: initialize INV
EXEC fnd_profile.put('MFG_ORGANIZATION_ID', 207);   -- M1 Seattle
```

But for SELECTs, just **filter by `ORGANIZATION_ID` explicitly**.

## Tables

### Item master + orgs

| Table | Purpose |
|---|---|
| `MTL_SYSTEM_ITEMS_B` | Item master — one row per **item × organization** (so the same item repeats per org) |
| `MTL_SYSTEM_ITEMS_TL` | Translated item descriptions |
| `MTL_PARAMETERS` | Inventory organizations (+ their default subinventory, costing, etc.) |
| `MTL_MATERIAL_STATUSES_B` | Item/material status master (Active, Inactive, Pending, …) |
| `MTL_MATERIAL_STATUSES_TL` | Translated material statuses |
| `MTL_UNITS_OF_MEASURE_TL` | UOM master (accessed via `MTL_UNITS_OF_MEASURE` APPS synonym) |

### Categories

| Table | Purpose |
|---|---|
| `MTL_CATEGORY_SETS_B` | Category set master (e.g. *Inv.Items*, *Purchasing*) |
| `MTL_CATEGORY_SETS_TL` | Translated names |
| `MTL_CATEGORIES_B` | Categories within a set (concatenated-segment structured) |
| `MTL_CATEGORIES_TL` | Translated category names |
| `MTL_ITEM_CATEGORIES` | Assignment of items to categories (per org) |

### Stock / locations

| Table | Purpose |
|---|---|
| `MTL_ONHAND_QUANTITIES_DETAIL` | Current on-hand (by item, org, subinventory, locator, lot, serial, revision) |
| `MTL_ONHAND_QUANTITIES` | **View** — aggregates the `_DETAIL` table |
| `MTL_SECONDARY_INVENTORIES` | Subinventory master |
| `MTL_ITEM_LOCATIONS` | Locator master (bin locations within subinventories) |
| `MTL_LOT_NUMBERS` | Lot numbers |
| `MTL_SERIAL_NUMBERS` | Serial numbers |

### Transactions

| Table | Purpose |
|---|---|
| `MTL_MATERIAL_TRANSACTIONS` | All on-hand-affecting transactions (history) |
| `MTL_TRANSACTION_TYPES` | Transaction type master (Miscellaneous Issue, PO Receipt, WIP Completion, …) |
| `MTL_TRANSACTIONS_INTERFACE` | Open interface for inbound transactions |
| `MTL_TXN_REQUEST_HEADERS` | Move Order / Pick Wave headers |
| `MTL_TXN_REQUEST_LINES` | Move Order lines |

### Costing

| Table | Purpose |
|---|---|
| `CST_ITEM_COSTS` | Item cost per organization + cost type |
| `CST_COST_TYPES` | Cost type master (Average, Standard, FIFO/LIFO, user-defined) |

## Canonical joins (all verified)

### Item master + category

```sql
SELECT msi.segment1            AS item_number,
       msi_tl.description,
       mp.organization_code,
       mck.concatenated_segments  AS category
FROM   mtl_system_items_b    msi
JOIN   mtl_system_items_tl   msi_tl ON msi_tl.inventory_item_id = msi.inventory_item_id
                                   AND msi_tl.organization_id    = msi.organization_id
                                   AND msi_tl.language           = USERENV('LANG')
JOIN   mtl_parameters        mp  ON mp.organization_id = msi.organization_id
JOIN   mtl_item_categories   mic ON mic.inventory_item_id = msi.inventory_item_id
                                AND mic.organization_id    = msi.organization_id
JOIN   mtl_categories_b_kfv  mck ON mck.category_id = mic.category_id
WHERE  msi.organization_id = 207;           -- M1
```

Use `MTL_CATEGORIES_B_KFV` (the KFF view) for `concatenated_segments`. The base table `MTL_CATEGORIES_B` stores the raw `SEGMENT1..SEGMENTn` columns but no pre-concatenated column.

### Onhand quantity by item + subinventory + locator

```sql
SELECT msi.segment1 AS item,
       oqd.subinventory_code,
       mil.segment1 AS locator,
       oqd.lot_number,
       oqd.transaction_quantity AS onhand
FROM   mtl_onhand_quantities_detail oqd
JOIN   mtl_system_items_b           msi ON msi.inventory_item_id = oqd.inventory_item_id
                                       AND msi.organization_id    = oqd.organization_id
LEFT JOIN mtl_item_locations        mil ON mil.inventory_location_id = oqd.locator_id
                                       AND mil.organization_id       = oqd.organization_id
WHERE  oqd.organization_id = 207
AND    oqd.transaction_quantity > 0
ORDER  BY msi.segment1, oqd.subinventory_code;
```

*(Or use the aggregated view `MTL_ONHAND_QUANTITIES` if you don't need the lot/locator detail.)*

### Material transactions (history)

```sql
SELECT mmt.transaction_id,
       mmt.transaction_date,
       mtt.transaction_type_name,
       msi.segment1         AS item,
       mmt.subinventory_code,
       mmt.transaction_quantity,
       mmt.transaction_uom,
       mmt.transaction_source_type_id,
       mmt.transaction_source_id,
       mmt.reference         AS reference
FROM   mtl_material_transactions mmt
JOIN   mtl_transaction_types     mtt ON mtt.transaction_type_id = mmt.transaction_type_id
JOIN   mtl_system_items_b        msi ON msi.inventory_item_id = mmt.inventory_item_id
                                    AND msi.organization_id    = mmt.organization_id
WHERE  mmt.organization_id   = 207
AND    mmt.transaction_date >= TRUNC(SYSDATE - 7)
ORDER  BY mmt.transaction_date DESC;
```

### Move Order (Txn Request) header → lines

```sql
SELECT h.header_id,
       h.request_number,
       h.move_order_type,
       h.transaction_type_id,
       l.line_number,
       msi.segment1  AS item,
       l.quantity,
       l.from_subinventory_code,
       l.to_subinventory_code,
       l.line_status
FROM   mtl_txn_request_headers  h
JOIN   mtl_txn_request_lines    l   ON l.header_id           = h.header_id
JOIN   mtl_system_items_b       msi ON msi.inventory_item_id = l.inventory_item_id
                                   AND msi.organization_id    = l.organization_id
WHERE  h.organization_id = 207;
```

### Item cost

```sql
SELECT msi.segment1      AS item,
       ct.cost_type,
       ic.item_cost,
       ic.pl_material,
       ic.pl_material_overhead,
       ic.pl_resource,
       ic.pl_outside_processing,
       ic.pl_overhead
FROM   cst_item_costs       ic
JOIN   cst_cost_types       ct  ON ct.cost_type_id = ic.cost_type_id
JOIN   mtl_system_items_b   msi ON msi.inventory_item_id = ic.inventory_item_id
                               AND msi.organization_id    = ic.organization_id
WHERE  ic.organization_id = 207
AND    ct.cost_type       = 'Frozen';         -- standard cost
```

## Commonly looked-up IDs on Vision

| Org | `ORGANIZATION_ID` | `ORGANIZATION_CODE` |
|---|---|---|
| Vision Operations (master) | `204` | `V1` |
| Seattle Manufacturing | `207` | `M1` |
| Austin Manufacturing | `208` | `M2` |

Verify on your instance:
```sql
SELECT organization_id, organization_code, organization_name
FROM   mtl_parameters ORDER BY organization_code;
```

## Next

Back to [../Base_Tables/](../Base_Tables/) · See also [../Oracle_APIs/INV/create_item.sql](../Oracle_APIs/INV/create_item.sql) for the matching API script.
