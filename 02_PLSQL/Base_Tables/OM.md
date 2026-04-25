# OM — Order Management & Shipping Base Tables & Joins (SQL & PL/SQL for EBS)

Verified against the live Vision R12.2.12 instance.

All `_ALL` tables carry `ORG_ID`. Set MOAC first:

```sql
EXEC mo_global.set_policy_context('S', 204);     -- Vision Operations
```

## Tables

### Orders

| Table | ORG_ID | Purpose |
|---|---|---|
| `OE_ORDER_HEADERS_ALL` | ✅ | Order headers |
| `OE_ORDER_LINES_ALL` | ✅ | Order lines |
| `OE_TRANSACTION_TYPES_ALL` | ✅ | Order / line transaction type master |
| `OE_TRANSACTION_TYPES_TL` | — | Translated transaction type names |

### Shipping (WSH)

| Table | ORG_ID | Purpose |
|---|---|---|
| `WSH_DELIVERY_DETAILS` | ✅ | Shippable line / "delivery detail" — one per OE line being shipped |
| `WSH_NEW_DELIVERIES` | — | Delivery header (a truck / shipment) |
| `WSH_DELIVERY_ASSIGNMENTS` | — | Links delivery details to a delivery |

### Pricing (QP)

| Table | ORG_ID | Purpose |
|---|---|---|
| `QP_LIST_HEADERS_B` | — | Price list header. Translated name lives in `QP_LIST_HEADERS_TL` |
| `QP_LIST_HEADERS_TL` | — | Translated price-list names and descriptions |
| `QP_LIST_LINES` | — | Price list lines. **Does not** carry the item linkage — see next |
| `QP_PRICING_ATTRIBUTES` | — | Item linkage per price-list line: `product_attribute_context='ITEM'` + `product_attr_value=<inventory_item_id>` |

## Canonical joins (all verified)

### Order → Lines → Transaction Type → Customer

```sql
SELECT h.order_number,
       h.ordered_date,
       h.flow_status_code   AS header_status,
       ttl.name             AS order_type,
       p.party_name         AS customer,
       l.line_number,
       msi.segment1         AS item,
       l.ordered_quantity,
       l.unit_selling_price,
       l.flow_status_code   AS line_status
FROM   oe_order_headers_all       h
JOIN   oe_order_lines_all         l   ON l.header_id = h.header_id
JOIN   oe_transaction_types_all   tt  ON tt.transaction_type_id = h.order_type_id
JOIN   oe_transaction_types_tl    ttl ON ttl.transaction_type_id = tt.transaction_type_id
                                     AND ttl.language           = USERENV('LANG')
JOIN   hz_cust_accounts           ca  ON ca.cust_account_id = h.sold_to_org_id
JOIN   hz_parties                 p   ON p.party_id = ca.party_id
LEFT JOIN mtl_system_items_b      msi ON msi.inventory_item_id = l.inventory_item_id
                                     AND msi.organization_id    = l.ship_from_org_id
WHERE  h.org_id = 204
ORDER  BY h.order_number, l.line_number;
```

### Order Line → Delivery Detail → Delivery

```sql
SELECT h.order_number,
       l.line_number,
       msi.segment1         AS item,
       l.ordered_quantity,
       dd.released_status,
       dd.shipped_quantity,
       dn.name              AS delivery_name,
       dn.status_code       AS delivery_status,
       dn.initial_pickup_date,
       dn.ultimate_dropoff_date
FROM   oe_order_headers_all       h
JOIN   oe_order_lines_all         l  ON l.header_id = h.header_id
LEFT JOIN wsh_delivery_details    dd ON dd.source_line_id = l.line_id
                                     AND dd.source_code    = 'OE'
LEFT JOIN wsh_delivery_assignments da ON da.delivery_detail_id = dd.delivery_detail_id
LEFT JOIN wsh_new_deliveries      dn ON dn.delivery_id = da.delivery_id
JOIN   mtl_system_items_b         msi ON msi.inventory_item_id = l.inventory_item_id
                                     AND msi.organization_id    = l.ship_from_org_id
WHERE  h.org_id = 204;
```

### Order Line → Price List → Price List Line

```sql
SELECT h.order_number,
       l.line_number,
       qph_tl.name          AS price_list,
       qph.currency_code,
       qpl.operand          AS list_price,
       l.unit_list_price,
       l.unit_selling_price,
       (l.unit_list_price - l.unit_selling_price) AS total_discount
FROM   oe_order_headers_all h
JOIN   oe_order_lines_all   l     ON l.header_id = h.header_id
LEFT JOIN qp_list_headers_b qph   ON qph.list_header_id = l.price_list_id
LEFT JOIN qp_list_headers_tl qph_tl ON qph_tl.list_header_id = qph.list_header_id
                                    AND qph_tl.language      = USERENV('LANG')
LEFT JOIN qp_list_lines     qpl   ON qpl.list_header_id    = qph.list_header_id
                                  AND qpl.list_line_type_code = 'PLL'              -- Price List Line
LEFT JOIN qp_pricing_attributes qpa ON qpa.list_line_id = qpl.list_line_id
                                    AND qpa.product_attribute_context = 'ITEM'
                                    AND qpa.product_attr_value        = TO_CHAR(l.inventory_item_id)
WHERE  h.org_id = 204;
```

### Booked orders by status

```sql
SELECT h.flow_status_code,
       COUNT(*) AS order_count,
       SUM(l.ordered_quantity * l.unit_selling_price) AS total_value
FROM   oe_order_headers_all h
JOIN   oe_order_lines_all   l ON l.header_id = h.header_id
WHERE  h.org_id = 204
AND    h.ordered_date >= TRUNC(SYSDATE, 'MM')
GROUP  BY h.flow_status_code;
```

## `flow_status_code` cheat sheet (headers + lines)

| Value | Meaning |
|---|---|
| `ENTERED` | Entered but not booked |
| `BOOKED` | Booked (firm commitment) |
| `AWAITING_SHIPPING` | Ready to pick and ship |
| `PICKED` | Picked but not shipped |
| `SHIPPED` | Shipped |
| `CLOSED` | Invoiced + receipt applied |
| `CANCELLED` | Cancelled |

## Next

Back to [../Base_Tables/](../Base_Tables/) · See also [../Oracle_APIs/OM/create_order.sql](../Oracle_APIs/OM/create_order.sql).
