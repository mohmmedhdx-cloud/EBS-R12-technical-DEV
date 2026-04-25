# GL — General Ledger Base Tables & Joins (SQL & PL/SQL for EBS)

Verified against the live Vision R12.2.12 instance.

GL tables are **not partitioned by OU** — they're partitioned by **`LEDGER_ID`** (formerly `SET_OF_BOOKS_ID`). Only `GL_JE_BATCHES` carries an informational `ORG_ID` (the requesting OU for intercompany) — it's not used by MOAC.

No `mo_global.set_policy_context` needed for GL queries. Always filter by `LEDGER_ID` (or join to `GL_LEDGERS` and filter by name/short-name).

## Tables

### Journal structure

| Table | Purpose |
|---|---|
| `GL_JE_BATCHES` | Batch (header above headers). Has `ORG_ID` but informational only |
| `GL_JE_HEADERS` | Journal header (one per source document, e.g. one invoice's GL entry) |
| `GL_JE_LINES` | Journal lines — **all balancing entries for a header live here** |
| `GL_JE_CATEGORIES` | APPS **view** for category master (`AP Invoices`, `Payroll`, …) |
| `GL_JE_CATEGORIES_TL` | Translated names |
| `GL_JE_SOURCES` | APPS **view** for source master (`Payables`, `Receivables`, `Manual`, …) |
| `GL_JE_SOURCES_TL` | Translated source names |
| `GL_INTERFACE` | Open interface table for custom journal loads (→ *Journal Import*) |
| `GL_INTERFACE_CONTROL` | Journal Import run tracking + status |

### Chart of accounts / flexfield

| Table | Purpose |
|---|---|
| `GL_CODE_COMBINATIONS` | The **CCID** table — one row per valid accounting code combination |
| `GL_CODE_COMBINATIONS_KFV` | APPS **view** that concatenates segments into `SEGMENT1.SEGMENT2.…` |
| `FND_ID_FLEX_STRUCTURES` | KFF structure master (e.g. *Accounting Flexfield*) — owned by APPLSYS |
| `FND_ID_FLEX_SEGMENTS` | Segments per KFF structure |
| `FND_FLEX_VALUE_SETS` | Value sets attached to segments |
| `FND_FLEX_VALUES` | Allowed values for each value set |

### Ledger / setup

| Table | Purpose |
|---|---|
| `GL_LEDGERS` | Ledger master (R12 name; subsumes pre-R12 sets-of-books) |
| `GL_LEDGER_SET_ASSIGNMENTS` | Membership of ledgers in ledger sets |
| `GL_SETS_OF_BOOKS` | APPS **view** — backward-compat shim over `GL_LEDGERS` |
| `GL_PERIODS` | Accounting calendar periods |
| `GL_PERIOD_STATUSES` | Per-ledger + application period status (`Open`, `Closed`, `Never Opened`, `Future Enterable`) |
| `GL_BALANCES` | Periodic debit / credit totals per CCID per period per ledger |
| `GL_DAILY_CONVERSION_TYPES` | Daily rate types (`Corporate`, `Spot`, `User`, …) |
| `GL_DAILY_RATES` | Daily currency rates |
| `FND_CURRENCIES` | Currency master (owned by APPLSYS) |
| `FND_CURRENCIES_VL` | Translated currency names (view) |

## Canonical joins (all verified)

### Batch → Header → Line → CCID

```sql
SELECT b.name          AS batch_name,
       h.name          AS header_name,
       h.je_source,
       h.je_category,
       l.je_line_num,
       cc.segment1 || '.' ||
       cc.segment2 || '.' ||
       cc.segment3 || '.' ||
       cc.segment4 || '.' ||
       cc.segment5 AS account,
       l.entered_dr,
       l.entered_cr,
       l.accounted_dr,
       l.accounted_cr
FROM   gl_je_batches         b
JOIN   gl_je_headers         h  ON h.je_batch_id      = b.je_batch_id
JOIN   gl_je_lines           l  ON l.je_header_id     = h.je_header_id
JOIN   gl_code_combinations  cc ON cc.code_combination_id = l.code_combination_id
WHERE  h.ledger_id      = :ledger_id    -- e.g. 1 = Vision Operations (USA). Check your instance.
AND    h.status         = 'P'           -- P = Posted
AND    h.period_name    = :period_name  -- e.g. 'JAN-97' — use an existing posted period on your instance
ORDER  BY b.name, h.name, l.je_line_num;
```

*(Use `GL_CODE_COMBINATIONS_KFV.CONCATENATED_SEGMENTS` as a shortcut instead of concatenating manually.)*

### Ledger + currency + period

```sql
SELECT lg.name           AS ledger_name,
       lg.currency_code,
       lg.period_set_name,
       p.period_name,
       p.start_date,
       p.end_date,
       ps.closing_status
FROM   gl_ledgers           lg
JOIN   gl_periods           p  ON p.period_set_name = lg.period_set_name
JOIN   gl_period_statuses   ps ON ps.ledger_id      = lg.ledger_id
                              AND ps.period_name    = p.period_name
                              AND ps.application_id = 101                -- GL
WHERE  lg.ledger_id = :ledger_id
ORDER  BY p.start_date DESC;
```

### KFF metadata: structure → segments → value set → values

```sql
SELECT s.id_flex_num,
       s.id_flex_structure_code,
       g.segment_name,
       g.segment_num,
       g.application_column_name,
       vs.flex_value_set_name,
       fv.flex_value,
       fvtl.description
FROM   fnd_id_flex_structures s
JOIN   fnd_id_flex_segments   g    ON g.application_id = s.application_id
                                  AND g.id_flex_code   = s.id_flex_code
                                  AND g.id_flex_num    = s.id_flex_num
LEFT JOIN fnd_flex_value_sets vs   ON vs.flex_value_set_id = g.flex_value_set_id
LEFT JOIN fnd_flex_values     fv   ON fv.flex_value_set_id = vs.flex_value_set_id
LEFT JOIN fnd_flex_values_tl  fvtl ON fvtl.flex_value_id = fv.flex_value_id
                                  AND fvtl.language      = USERENV('LANG')
WHERE  s.application_id = 101
AND    s.id_flex_code   = 'GL#'
ORDER  BY g.segment_num, fv.flex_value;
```

### Period balance for a single account

```sql
SELECT cc.segment1 || '.' || cc.segment2 || '.' || cc.segment3 ||
       '.' || cc.segment4 || '.' || cc.segment5 AS account,
       b.period_name,
       b.currency_code,
       b.period_net_dr,
       b.period_net_cr,
       b.begin_balance_dr,
       b.begin_balance_cr,
       (NVL(b.begin_balance_dr,0) + NVL(b.period_net_dr,0))
       - (NVL(b.begin_balance_cr,0) + NVL(b.period_net_cr,0)) AS ending_balance
FROM   gl_balances           b
JOIN   gl_code_combinations  cc ON cc.code_combination_id = b.code_combination_id
WHERE  b.ledger_id     = :ledger_id         -- e.g. 1 for Vision USA
AND    b.period_name   = :period_name       -- e.g. 'JAN-97'
AND    b.currency_code = 'USD'
AND    cc.segment4     = :natural_account   -- the natural-account segment value
ORDER  BY account;
```

### Daily rates (for FX conversion)

```sql
SELECT from_currency,
       to_currency,
       conversion_type,
       conversion_date,
       conversion_rate
FROM   gl_daily_rates
WHERE  from_currency     = 'EUR'
AND    to_currency       = 'USD'
AND    conversion_type   = 'Corporate'
AND    conversion_date BETWEEN ADD_MONTHS(TRUNC(SYSDATE,'MM'), -1) AND TRUNC(SYSDATE);
```

### Open Interface — feeding GL_INTERFACE

```sql
INSERT INTO gl_interface (
    status, set_of_books_id, ledger_id,
    accounting_date, currency_code,
    date_created, created_by, actual_flag,
    user_je_category_name, user_je_source_name,
    segment1, segment2, segment3, segment4, segment5,
    entered_dr, entered_cr, reference1, group_id
) VALUES (
    'NEW', 2021, 2021,
    TRUNC(SYSDATE), 'USD',
    SYSDATE, fnd_global.user_id, 'A',
    'Adjustment', 'Manual',
    '01','000','1100','0000','000',
    100, 0, 'XXC-LOAD-001', :group_id
);
-- Then submit program: "Journal Import" (short name GLLEZL), passing :group_id.
```

## Commonly looked-up IDs on Vision

| Ledger | `LEDGER_ID` |
|---|---|
| Vision Operations (USA) | `1` *(on a default Vision 12.2.12 VM)* |

**The exact ID varies by instance** — the Vision templates have shuffled numbers across releases. Confirm with:
```sql
SELECT ledger_id, name, short_name, currency_code FROM gl_ledgers ORDER BY name;
```

## Next

Back to [../Base_Tables/](../Base_Tables/).
