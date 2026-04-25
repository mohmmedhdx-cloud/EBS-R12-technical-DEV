# Base Tables per Module — SQL & PL/SQL for EBS

Canonical base-table reference for the most-used EBS R12 modules. Every table and every join below was **verified against a live Vision R12.2.12 instance** (`apps/apps@EBSDB`) on 2026-04-21 — if it's listed, it exists and the sample joins return rows.

## Module files

| # | Module | What's inside |
|---|---|---|
| 1 | [HRMS.md](HRMS.md) | People, assignments, jobs, grades, positions, orgs, locations, payroll, absences |
| 2 | [AP.md](AP.md) | Invoices, distributions, payments, holds, suppliers, terms, SLA accounting |
| 3 | [AR.md](AR.md) | TCA parties / customer accounts / sites / contacts + transactions, receipts, adjustments |
| 4 | [GL.md](GL.md) | Journal batches / headers / lines, code combinations, KFF segments, balances, periods |
| 5 | [INV.md](INV.md) | Items master, categories, on-hand, transactions, move orders, costing |
| 6 | [PO.md](PO.md) | PO header / lines / shipments / distributions, requisitions, receiving (RCV) |
| 7 | [OM.md](OM.md) | Order headers / lines, transaction types, shipping (WSH), pricing (QP) |
| 8 | [FND.md](FND.md) | Users, responsibilities, menus, functions, concurrent requests, lookups, profiles |

## Multi-Org Access Control (MOAC) cheat sheet

| Module | OU-aware? | Column | Notes |
|---|---|---|---|
| HRMS | no | `BUSINESS_GROUP_ID` | HR is partitioned by BG, not OU |
| AP | **yes** | `ORG_ID` | All `_ALL` tables — set MOAC first |
| AR | **yes** | `ORG_ID` | `_ALL` tables; `HZ_*` are global |
| GL | no | `LEDGER_ID` | Partitioned by ledger, not OU |
| INV | partial | `ORGANIZATION_ID` | Partitioned by inventory org, not OU |
| PO | **yes** | `ORG_ID` | All `_ALL` tables |
| OM | **yes** | `ORG_ID` | All `_ALL` tables |
| FND | no | — | Global |

**Set MOAC before querying any `_ALL` table in AP / AR / PO / OM:**

```sql
EXEC mo_global.set_policy_context('S', 204);        -- Vision Operations
-- or the full session initialization:
EXEC fnd_global.apps_initialize(
        user_id      => 1318,       -- OPERATIONS
        resp_id      => 50855,      -- AP Manager etc.
        resp_appl_id => 200);
```

Without this, `SELECT * FROM ap_invoices_all` from sqlplus returns **zero rows** even when invoices exist.

## How to run the sample joins

Every `.md` file's SQL blocks are copy-pasteable. From sqlplus:

```bash
sqlplus apps/apps@EBSDB
```

Then paste the block. Prefix with `EXEC mo_global.set_policy_context('S', 204);` for any module marked OU-aware above.

## Next

Back to [../](../) for the topic index.
