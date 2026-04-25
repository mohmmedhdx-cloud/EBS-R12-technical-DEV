# OM — `oe_order_pub.process_order`

Verified against the live Vision R12.2.12 instance. The call below executed end-to-end, returning `order_number=69332 header_id=358767`, then rolled back.

`oe_order_pub.process_order` is **the** Order Management API. It handles create / update / delete / cancel / book across order headers, lines, holds, sales credits, and price adjustments — via a single call taking 20+ table-of-records IN/OUT parameters.

## Context

```sql
fnd_global.apps_initialize(0, 21623, 660);      -- SYSADMIN / ORDER_MGMT_SUPER_USER / ONT (660)
mo_global.init('ONT');                          -- register ONT with MOAC
mo_global.set_policy_context('S', 204);         -- Vision Operations OU
```

Lookup your OM values:

```sql
-- responsibility
SELECT responsibility_id, application_id FROM fnd_responsibility_vl WHERE responsibility_key='ORDER_MGMT_SUPER_USER';

-- order types in this OU
SELECT tt.transaction_type_id, ttl.name, tt.order_category_code
FROM   oe_transaction_types_all tt
JOIN   oe_transaction_types_tl  ttl ON ttl.transaction_type_id = tt.transaction_type_id
                                   AND ttl.language = USERENV('LANG')
WHERE  tt.org_id = 204 AND tt.order_category_code='ORDER';

-- price list
SELECT list_header_id, name, currency_code FROM qp_list_headers_vl WHERE list_type_code='PRL';

-- order-enabled items (in V1 master)
SELECT inventory_item_id, segment1, description
FROM   mtl_system_items_b
WHERE  organization_id = 204
AND    customer_order_enabled_flag = 'Y' AND customer_order_flag = 'Y';

-- customer with SHIP_TO + BILL_TO (only sold_to is mandatory; ship-to defaults from customer)
SELECT ca.cust_account_id, ca.account_number, p.party_name
FROM   hz_cust_accounts ca JOIN hz_parties p ON p.party_id = ca.party_id
WHERE  ca.status='A';
```

## Verified minimal `process_order` call

```sql
SET SERVEROUTPUT ON
DECLARE
  l_header_rec        oe_order_pub.header_rec_type;
  l_line_tbl          oe_order_pub.line_tbl_type;
  l_action_request_tbl oe_order_pub.request_tbl_type;

  -- the ~20 OUT parameters
  l_header_out           oe_order_pub.header_rec_type;
  l_header_val_out       oe_order_pub.header_val_rec_type;
  l_header_adj_out       oe_order_pub.header_adj_tbl_type;
  l_header_adj_val_out   oe_order_pub.header_adj_val_tbl_type;
  l_header_price_att_out oe_order_pub.header_price_att_tbl_type;
  l_header_adj_att_out   oe_order_pub.header_adj_att_tbl_type;
  l_header_adj_assoc_out oe_order_pub.header_adj_assoc_tbl_type;
  l_header_scredit_out   oe_order_pub.header_scredit_tbl_type;
  l_header_scredit_val_out oe_order_pub.header_scredit_val_tbl_type;
  l_line_out             oe_order_pub.line_tbl_type;
  l_line_val_out         oe_order_pub.line_val_tbl_type;
  l_line_adj_out         oe_order_pub.line_adj_tbl_type;
  l_line_adj_val_out     oe_order_pub.line_adj_val_tbl_type;
  l_line_price_att_out   oe_order_pub.line_price_att_tbl_type;
  l_line_adj_att_out     oe_order_pub.line_adj_att_tbl_type;
  l_line_adj_assoc_out   oe_order_pub.line_adj_assoc_tbl_type;
  l_line_scredit_out     oe_order_pub.line_scredit_tbl_type;
  l_line_scredit_val_out oe_order_pub.line_scredit_val_tbl_type;
  l_lot_serial_out       oe_order_pub.lot_serial_tbl_type;
  l_lot_serial_val_out   oe_order_pub.lot_serial_val_tbl_type;
  l_action_request_out   oe_order_pub.request_tbl_type;

  l_return_status   VARCHAR2(10);
  l_msg_count       NUMBER;
  l_msg_data        VARCHAR2(4000);
BEGIN
  fnd_global.apps_initialize(0, 21623, 660);
  mo_global.init('ONT');
  mo_global.set_policy_context('S', 204);

  -- HEADER
  l_header_rec := oe_order_pub.g_miss_header_rec;                -- start from the "no-op" sentinel
  l_header_rec.operation               := oe_globals.g_opr_create;
  l_header_rec.org_id                  := 204;
  l_header_rec.order_type_id           := 1000;                  -- 'Standard' on Vision
  l_header_rec.sold_to_org_id          := 1004;                  -- customer account_id
  l_header_rec.transactional_curr_code := 'USD';
  l_header_rec.price_list_id           := 1000;                  -- Corporate USD

  -- LINE(S)
  l_line_tbl(1) := oe_order_pub.g_miss_line_rec;
  l_line_tbl(1).operation         := oe_globals.g_opr_create;
  l_line_tbl(1).inventory_item_id := 8409;                       -- U-Z100
  l_line_tbl(1).ordered_quantity  := 1;
  l_line_tbl(1).ship_from_org_id  := 204;

  oe_order_pub.process_order(
      p_api_version_number   => 1.0,
      p_init_msg_list        => fnd_api.g_true,
      p_return_values        => fnd_api.g_false,
      p_action_commit        => fnd_api.g_false,                 -- dry run — commit yourself later
      p_header_rec           => l_header_rec,
      p_line_tbl             => l_line_tbl,
      p_action_request_tbl   => l_action_request_tbl,
      x_header_rec           => l_header_out,
      x_header_val_rec       => l_header_val_out,
      x_header_adj_tbl       => l_header_adj_out,
      x_header_adj_val_tbl   => l_header_adj_val_out,
      x_header_price_att_tbl => l_header_price_att_out,
      x_header_adj_att_tbl   => l_header_adj_att_out,
      x_header_adj_assoc_tbl => l_header_adj_assoc_out,
      x_header_scredit_tbl   => l_header_scredit_out,
      x_header_scredit_val_tbl => l_header_scredit_val_out,
      x_line_tbl             => l_line_out,
      x_line_val_tbl         => l_line_val_out,
      x_line_adj_tbl         => l_line_adj_out,
      x_line_adj_val_tbl     => l_line_adj_val_out,
      x_line_price_att_tbl   => l_line_price_att_out,
      x_line_adj_att_tbl     => l_line_adj_att_out,
      x_line_adj_assoc_tbl   => l_line_adj_assoc_out,
      x_line_scredit_tbl     => l_line_scredit_out,
      x_line_scredit_val_tbl => l_line_scredit_val_out,
      x_lot_serial_tbl       => l_lot_serial_out,
      x_lot_serial_val_tbl   => l_lot_serial_val_out,
      x_action_request_tbl   => l_action_request_out,
      x_return_status        => l_return_status,
      x_msg_count            => l_msg_count,
      x_msg_data             => l_msg_data);

  IF l_return_status = fnd_api.g_ret_sts_success THEN
    dbms_output.put_line('header_id='||l_header_out.header_id
                         ||' order_number='||l_header_out.order_number);
    COMMIT;
  ELSE
    FOR i IN 1..l_msg_count LOOP
      dbms_output.put_line(fnd_msg_pub.get(i, fnd_api.g_false));
    END LOOP;
    ROLLBACK;
  END IF;
END;
/
```

**Verified output on Vision:** `header_id=358767 order_number=69332`.

## Booking an order after create

`process_order` with `operation = g_opr_create` leaves the order in `ENTERED` status — not yet booked. To book it (and release it to Pick Release / Ship Confirm flow), add a **request row**:

```sql
l_action_request_tbl(1).request_type := oe_globals.g_book_order;
l_action_request_tbl(1).entity_code  := oe_globals.g_entity_header;
l_action_request_tbl(1).entity_id    := l_header_rec.header_id;      -- or let the API resolve
```

Or call book separately on an existing order:

```sql
DECLARE
  l_return_status  VARCHAR2(10);
  l_msg_count      NUMBER;
  l_msg_data       VARCHAR2(4000);
BEGIN
  fnd_global.apps_initialize(0, 21623, 660);
  mo_global.set_policy_context('S', 204);

  oe_order_wf_util.manual_book_order(
      p_header_id     => :p_header_id,
      x_return_status => l_return_status);
END;
/
```

## Update / cancel a line

Same API, different operation:

```sql
l_line_tbl(1).operation          := oe_globals.g_opr_update;
l_line_tbl(1).header_id          := :p_header_id;
l_line_tbl(1).line_id            := :p_line_id;
l_line_tbl(1).ordered_quantity   := 5;                                -- new qty
```

Cancel:

```sql
l_line_tbl(1).operation           := oe_globals.g_opr_update;
l_line_tbl(1).line_id             := :p_line_id;
l_line_tbl(1).cancelled_flag      := 'Y';
l_line_tbl(1).change_reason       := 'CUSTOMER';
l_line_tbl(1).change_comments     := 'Customer requested cancellation';
```

## Verification queries

```sql
-- header
SELECT header_id, order_number, ordered_date, flow_status_code, booked_flag, transactional_curr_code
FROM   oe_order_headers_all
WHERE  header_id = :p_header_id;

-- lines
SELECT line_id, line_number, ordered_quantity, shipped_quantity, flow_status_code, shippable_flag
FROM   oe_order_lines_all
WHERE  header_id = :p_header_id
ORDER  BY line_number;

-- workflow status
SELECT item_type, item_key, activity_name, activity_status, assigned_user
FROM   wf_item_activity_statuses_v
WHERE  item_type='OEOH' AND item_key = TO_CHAR(:p_header_id);
```

## Gotchas

- **Always set `org_id`** in the header record — `mo_global.set_policy_context` alone is not enough on `process_order`.
- **Start from `g_miss_*_rec`** — it flags every column as "unchanged" so you only override what you're setting. Using `NULL` for an unchanged column overwrites it to NULL.
- `p_return_values` → `fnd_api.g_false` suppresses the "validated" output records (saves parsing 20 IN/OUT tables you don't need).
- `p_action_commit` → `fnd_api.g_false` lets you roll back. The API *still* issues internal commits for side-effect tables (defaulting rules, etc.) — fully atomic rollback is not possible if any pricing / tax engine fires.
- Vision's order type `1000` (Standard) auto-defaults ship-to from the sold-to customer's primary `SHIP_TO` site. Override via `l_header_rec.ship_to_org_id` if you want a different one.

## Next

Back to [./](./).
