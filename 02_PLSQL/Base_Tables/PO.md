# PO — Purchasing & Receiving Base Tables & Joins (SQL & PL/SQL for EBS)

Verified against the live Vision R12.2.12 instance.

Every `_ALL` table carries `ORG_ID`. Set MOAC first:

```sql
EXEC mo_global.set_policy_context('S', 204);     -- Vision Operations
```

## Tables

### Requisitions

| Table | ORG_ID | Purpose |
|---|---|---|
| `PO_REQUISITION_HEADERS_ALL` | ✅ | Requisition headers (INTERNAL / PURCHASE) |
| `PO_REQUISITION_LINES_ALL` | ✅ | Requisition lines |
| `PO_REQ_DISTRIBUTIONS_ALL` | — | Requisition distributions (accounting) |

### Purchase Orders

| Table | ORG_ID | Purpose |
|---|---|---|
| `PO_HEADERS_ALL` | ✅ | PO / Blanket / Contract / Standard PO headers |
| `PO_LINES_ALL` | ✅ | PO line (what is being bought) |
| `PO_LINE_LOCATIONS_ALL` | ✅ | Shipment / schedule (when / where to deliver) |
| `PO_DISTRIBUTIONS_ALL` | ✅ | Accounting distributions per shipment |
| `PO_RELEASES_ALL` | ✅ | Releases against blanket agreements |
| `PO_ACTION_HISTORY` | — | Approval / acceptance / rejection actions |
| `PO_DOCUMENT_TYPES_ALL_B` | ✅ | Document type master (STANDARD, BLANKET, CONTRACT, PLANNED, …) |
| `PO_DOCUMENT_TYPES_ALL_TL` | ✅ | Translated names |
| `PO_SYSTEM_PARAMETERS_ALL` | ✅ | Per-OU PO setup |

### Suppliers (shared with AP — legacy names)

| Table | ORG_ID | Purpose |
|---|---|---|
| `PO_VENDORS` | — | R12 **view** over `AP_SUPPLIERS` |
| `PO_VENDOR_SITES_ALL` | ✅ | R12 **view** over `AP_SUPPLIER_SITES_ALL` |
| `PO_VENDOR_CONTACTS` | — | R12 **view** over `AP_SUPPLIER_CONTACTS` |

### Receiving

| Table | ORG_ID | Purpose |
|---|---|---|
| `RCV_SHIPMENT_HEADERS` | — | One row per ASN / receipt (shipment) |
| `RCV_SHIPMENT_LINES` | — | Lines on each shipment |
| `RCV_TRANSACTIONS` | — | Receiving transactions (RECEIVE, DELIVER, RETURN TO VENDOR, CORRECT, …) |

## Canonical joins (all verified)

### PO header → line → shipment → distribution → supplier

```sql
SELECT h.segment1            AS po_number,
       h.type_lookup_code    AS po_type,
       h.authorization_status,
       s.vendor_name,
       ss.vendor_site_code,
       l.line_num,
       msi.segment1          AS item,
       l.unit_price,
       ll.quantity,
       ll.promised_date,
       d.code_combination_id AS charge_account,
       d.distribution_num
FROM   po_headers_all         h
JOIN   po_lines_all           l   ON l.po_header_id      = h.po_header_id
JOIN   po_line_locations_all  ll  ON ll.po_line_id       = l.po_line_id
JOIN   po_distributions_all   d   ON d.line_location_id  = ll.line_location_id
LEFT JOIN mtl_system_items_b  msi ON msi.inventory_item_id = l.item_id
                                 AND msi.organization_id   = NVL(d.destination_organization_id, 204)
JOIN   po_vendors             s   ON s.vendor_id         = h.vendor_id
LEFT JOIN po_vendor_sites_all ss  ON ss.vendor_site_id   = h.vendor_site_id
WHERE  h.org_id = 204
ORDER  BY h.segment1, l.line_num, ll.shipment_num, d.distribution_num;
```

### Requisition → lines → distributions

```sql
SELECT h.segment1  AS requisition_number,
       h.type_lookup_code,
       h.authorization_status,
       l.line_num,
       l.item_description,
       l.quantity,
       l.unit_price,
       d.distribution_num,
       d.code_combination_id
FROM   po_requisition_headers_all h
JOIN   po_requisition_lines_all   l ON l.requisition_header_id = h.requisition_header_id
JOIN   po_req_distributions_all   d ON d.requisition_line_id   = l.requisition_line_id
WHERE  h.org_id = 204;
```

### PO approval history

```sql
SELECT h.segment1     AS po_number,
       ah.sequence_num,
       ah.action_code,
       ah.action_date,
       papf.full_name  AS actor,
       ah.note
FROM   po_headers_all    h
JOIN   po_action_history ah  ON ah.object_id           = h.po_header_id
                            AND ah.object_type_code    = 'PO'
LEFT JOIN per_all_people_f papf ON papf.person_id      = ah.employee_id
                                AND SYSDATE BETWEEN papf.effective_start_date
                                                AND papf.effective_end_date
WHERE  h.org_id = 204
ORDER  BY h.segment1, ah.sequence_num;
```

### Receiving: PO → shipment header → lines → transactions

```sql
SELECT h.segment1        AS po_number,
       rsh.receipt_num,
       rsh.receipt_source_code,
       rsh.shipment_num,
       rsl.line_num,
       msi.segment1      AS item,
       rt.transaction_type,
       rt.transaction_date,
       rt.quantity,
       rt.unit_of_measure
FROM   po_headers_all        h
JOIN   rcv_shipment_lines    rsl ON rsl.po_header_id = h.po_header_id
JOIN   rcv_shipment_headers  rsh ON rsh.shipment_header_id = rsl.shipment_header_id
JOIN   rcv_transactions      rt  ON rt.shipment_line_id = rsl.shipment_line_id
LEFT JOIN mtl_system_items_b msi ON msi.inventory_item_id = rsl.item_id
                                AND msi.organization_id    = rsl.to_organization_id
WHERE  h.org_id = 204;
```

### Blanket Release chain

```sql
SELECT h.segment1       AS blanket_po,
       r.release_num,
       r.release_date,
       r.authorization_status,
       ll.shipment_num,
       ll.quantity,
       ll.promised_date
FROM   po_headers_all        h
JOIN   po_releases_all       r  ON r.po_header_id = h.po_header_id
JOIN   po_line_locations_all ll ON ll.po_release_id = r.po_release_id
WHERE  h.org_id = 204
AND    h.type_lookup_code = 'BLANKET';
```

### Commonly looked-up IDs on Vision

```sql
SELECT document_type_code, document_subtype, document_name
FROM   po_document_types_all_b
WHERE  org_id = 204
ORDER  BY document_type_code;
```

## Next

Back to [../Base_Tables/](../Base_Tables/).
