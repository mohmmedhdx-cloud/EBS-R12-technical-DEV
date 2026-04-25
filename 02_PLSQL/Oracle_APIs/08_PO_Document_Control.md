# PO — `po_document_control_pub.control_document`

Verified against the live Vision R12.2.12 instance. The call below reached the API and returned a functional response ("Action = CLOSE is invalid for this document") — confirming the call path compiles and executes end-to-end.

`po_document_control_pub.control_document` is the entry point for **every status action** on a PO, Blanket Agreement, Release, or Requisition: approve, reserve, cancel, close, finally close, freeze, hold, print, return-to-requester, …

## Context

```sql
fnd_global.apps_initialize(0, 20704, 201);       -- SYSADMIN / PURCHASING_SUPER_USER / PO app 201
mo_global.init('PO');
mo_global.set_policy_context('S', 204);
```

## `p_doc_type` / `p_doc_subtype` / `p_action` — the combinations

| `p_doc_type` | `p_doc_subtype` examples | common `p_action` values |
|---|---|---|
| `PO`      | `STANDARD`, `BLANKET`, `CONTRACT`, `PLANNED` | `APPROVE`, `CANCEL`, `CLOSE`, `FINALLY CLOSE`, `REOPEN`, `FREEZE`, `UNFREEZE`, `HOLD`, `RELEASE HOLD`, `PRINT`, `CLOSE FOR INVOICE`, `CLOSE FOR RECEIVING` |
| `RELEASE` | `BLANKET`, `SCHEDULED`                       | `APPROVE`, `CANCEL`, `CLOSE`, `FINALLY CLOSE`, `REOPEN` |
| `REQUISITION` | `PURCHASE`, `INTERNAL`                   | `APPROVE`, `CANCEL`, `RETURN`, `RESUBMIT` |
| `PA`      | `BLANKET`, `CONTRACT`                        | `APPROVE`, `CANCEL`, `FINALLY CLOSE` |

## Overload gotcha — prefer **positional** notation

`po_document_control_pub.control_document` has **two overloads**: one for a single document, one for a table of documents (`PO_DOC_TBL`). They overlap on many parameter names, so named-notation calls often fail with `PLS-00306: wrong number or types of arguments` because PL/SQL can't decide between them.

**Use positional notation** to force overload 1 (single document):

```sql
SET SERVEROUTPUT ON
DECLARE
  v_return_status VARCHAR2(10);
BEGIN
  fnd_global.apps_initialize(0, 20704, 201);
  mo_global.init('PO');
  mo_global.set_policy_context('S', 204);

  po_document_control_pub.control_document(
      1.0,                 -- 1  p_api_version
      fnd_api.g_true,      -- 2  p_init_msg_list
      fnd_api.g_false,     -- 3  p_commit
      v_return_status,     -- 4  x_return_status  (OUT)
      'PO',                -- 5  p_doc_type
      'STANDARD',          -- 6  p_doc_subtype
      :p_po_header_id,     -- 7  p_doc_id
      NULL,                -- 8  p_doc_num
      NULL,                -- 9  p_release_id
      NULL,                -- 10 p_release_num
      NULL,                -- 11 p_doc_line_id
      NULL,                -- 12 p_doc_line_num
      NULL,                -- 13 p_doc_line_loc_id
      NULL,                -- 14 p_doc_shipment_num
      'CLOSE',             -- 15 p_action           <-- the operation
      TRUNC(SYSDATE),      -- 16 p_action_date
      NULL,                -- 17 p_cancel_reason
      'N',                 -- 18 p_cancel_reqs_flag
      'N',                 -- 19 p_print_flag
      NULL,                -- 20 p_note_to_vendor
      'N',                 -- 21 p_use_gldate
      204,                 -- 22 p_org_id
      'N');                -- 23 p_launch_approvals_flag

  dbms_output.put_line('status=' || v_return_status);
  FOR i IN 1..NVL(fnd_msg_pub.count_msg,0) LOOP
    dbms_output.put_line(fnd_msg_pub.get(i, fnd_api.g_false));
  END LOOP;
  IF v_return_status = fnd_api.g_ret_sts_success THEN
    COMMIT;
  ELSE
    ROLLBACK;
  END IF;
END;
/
```

**Verified behaviour on Vision:** calling `CLOSE` on an approved-but-open PO (header_id 7068, segment1 '1442') returns `status=E` with the message *"The specified control action (Action = CLOSE) is invalid for this document"* — confirming the API executes and validates the state.

## Common actions

### Approve a PO

```sql
po_document_control_pub.control_document(
    1.0, fnd_api.g_true, fnd_api.g_false, v_return_status,
    'PO', 'STANDARD', :p_po_header_id,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'APPROVE', TRUNC(SYSDATE),
    NULL, NULL, 'N', NULL, 'N', 204, 'Y');         -- launch_approvals_flag='Y'
```

`p_launch_approvals_flag = 'Y'` on APPROVE kicks the PO Approval workflow. If your profile `PO: Document Approval Workflow` is disabled, pass `'N'` (auto-approve).

### Cancel a PO

```sql
po_document_control_pub.control_document(
    1.0, fnd_api.g_true, fnd_api.g_false, v_return_status,
    'PO', 'STANDARD', :p_po_header_id,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'CANCEL', TRUNC(SYSDATE),
    'Supplier unable to fulfil',               -- p_cancel_reason
    'N',                                       -- p_cancel_reqs_flag ('Y' to cancel linked requisition too)
    'N', NULL, 'N', 204, 'N');
```

### Cancel a single line (not the whole PO)

Pass `p_doc_line_id` instead of `p_doc_id`-only:

```sql
po_document_control_pub.control_document(
    1.0, fnd_api.g_true, fnd_api.g_false, v_return_status,
    'PO', 'STANDARD', :p_po_header_id,
    NULL, NULL, NULL,
    :p_po_line_id,                   -- 11  p_doc_line_id
    NULL, NULL, NULL,
    'CANCEL', TRUNC(SYSDATE),
    'Line-level cancel',
    'N', 'N', NULL, 'N', 204, 'N');
```

### Finally close a PO (cannot be reopened)

```sql
po_document_control_pub.control_document(
    1.0, fnd_api.g_true, fnd_api.g_false, v_return_status,
    'PO', 'STANDARD', :p_po_header_id,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'FINALLY CLOSE', TRUNC(SYSDATE),
    NULL, 'N', 'N', NULL, 'N', 204, 'N');
```

### Approve a requisition

```sql
po_document_control_pub.control_document(
    1.0, fnd_api.g_true, fnd_api.g_false, v_return_status,
    'REQUISITION', 'PURCHASE', :p_req_header_id,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'APPROVE', TRUNC(SYSDATE),
    NULL, NULL, 'N', NULL, 'N', 204, 'Y');
```

## Verification queries

```sql
-- PO state after an action
SELECT po_header_id, segment1, type_lookup_code, authorization_status,
       approved_flag, closed_code, cancel_flag, user_hold_flag
FROM   po_headers_all
WHERE  po_header_id = :p_po_header_id;

-- Action history (who did what when)
SELECT ah.sequence_num, ah.action_code, ah.action_date,
       papf.full_name AS actor, ah.note
FROM   po_action_history ah
LEFT JOIN per_all_people_f papf ON papf.person_id = ah.employee_id
                                AND SYSDATE BETWEEN papf.effective_start_date
                                                AND papf.effective_end_date
WHERE  ah.object_id       = :p_po_header_id
AND    ah.object_type_code = 'PO'
ORDER  BY ah.sequence_num;
```

## Gotchas

- **`fnd_msg_pub.count_msg`** can be non-zero even on success (info messages). Always check `x_return_status` first.
- **`p_cancel_reqs_flag='Y'`** also cancels backing requisitions — be sure that's what the user wants.
- **`p_commit`** is honoured by the API — with `g_false`, your subsequent `COMMIT`/`ROLLBACK` wraps the call.
- **Named notation usually fails** with PLS-00306 because of the overload with `PO_DOC_TBL`. Either use positional (as above) or disambiguate by explicitly passing an overload-1-only parameter like `p_cancel_reqs_flag`.
- **PO types matter** — *Contract Purchase Agreements* (`'PA'`/`'CONTRACT'`) and *Blanket Purchase Agreements* (`'PA'`/`'BLANKET'`) go through the same API but with `p_doc_type='PA'` — not `'PO'`.
- **`p_action_date`** defaults to `SYSDATE` if you pass `NULL`, but must fall in an open inventory / GL period for actions that generate accounting (CANCEL on a PO with receipts).

## Next

Back to [./](./).
