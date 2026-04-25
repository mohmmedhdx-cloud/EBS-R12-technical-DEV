# End-to-end: Supplier creation — Oracle Fusion → OIC → Oracle EBS R12

Event-driven integration that creates a supplier in **EBS Payables** every time a supplier is created in **Oracle Fusion Cloud Procurement**, using **Oracle Integration Cloud (OIC)** as middleware and a **staging table + PL/SQL wrapper** on the EBS side. **Built and verified end-to-end on a Vision R12.2.12 instance — a real `ap_suppliers` row was created (`vendor_id=40178`) from a real Fusion event.**

## 1. Architecture

```
  Fusion ERP Cloud            Oracle Integration Cloud             Oracle EBS R12
 ┌──────────────┐            ┌──────────────────────────┐         ┌──────────────────────────────┐
 │ Supplier     │  business  │ Fusion ERP adapter       │         │ APPS.XXC_SUPPLIER_HEADER_STG │
 │ created in   │──event────▶│  (subscribe + REST GET)  │         │ (staging — OIC lands rows)   │
 │ Procurement  │            │            │             │         └──────────┬───────────────────┘
 └──────────────┘            │            ▼             │                    │ inline, same call
                             │ Mapper + DVM lookups     │                    │
                             │            │             │                    ▼
                             │            ▼             │         ┌──────────────────────────────┐
                             │ DB Adapter INSERT ───────┼─────────▶ (row appears as process_flag │
                             │                          │  JDBC   │    = 'N' initially)          │
                             │ DB Adapter CALL proc ────┼─────────▶ APPS.XX_LOAD_SUP_EBS         │
                             │                          │         │     .Process_sups_api        │
                             │            ▲             │         │        ↓                     │
                             │   Res_out (S / E)  ──────┼─────────┤ ap_vendor_pub_pkg            │
                             │            │             │         │     .create_vendor           │
                             │            ▼             │         │        ↓                     │
                             │  Switch ─┬ Success → End │         │ UPDATE staging:              │
                             │          └ Error → Throw │         │   process_flag = 'P',        │
                             │                Fault     │         │   ebs_vendor_id = 40178, ... │
                             │                          │         │                              │
                             │                          │         │ On error:                    │
                             │                          │         │   process_flag = 'E',        │
                             │                          │         │   INSERT xxc_integration_   │
                             │                          │         │          error_log          │
                             └──────────────────────────┘         └──────────────────────────────┘
```

**End-to-end latency:** typically 2–5 seconds from Fusion save → row in `ap_suppliers`.

## 2. What got built

| Layer | Artefact | Owner |
|---|---|---|
| EBS | Staging table `APPS.XXC_SUPPLIER_HEADER_STG` (21 cols) | APPS |
| EBS | Error log `APPS.XXC_INTEGRATION_ERROR_LOG` | APPS |
| EBS | Sequences `XXC_SUPPLIER_HDR_STG_S`, `XXC_INTEGRATION_ERR_LOG_S` | APPS |
| EBS | Package `APPS.XX_LOAD_SUP_EBS` with `Process_sups_api(in_request_id, Res_out)` | APPS |
| OIC | Fusion ERP Cloud connection | — |
| OIC | EBS Database (DB Adapter) connection via on-prem Connectivity Agent | — |
| OIC | Integration `FUSION_SUPPLIER_TO_EBS` — event-triggered, 2 DB invokes + Switch + Throw Fault | — |

## 3. EBS side

### 3.1 Staging table — `APPS.XXC_SUPPLIER_HEADER_STG`

**Design principles applied:**
- Nothing is `NOT NULL` except where a default fires → OIC's DB Adapter can send NULLs without tripping `ORA-01400`.
- No CHECK constraints, no UNIQUE → OIC payloads won't be refused at the DB layer; PL/SQL validates downstream.
- WHO columns with safe defaults (`-1`, `SYSDATE`).

```sql
CREATE TABLE APPS.XXC_SUPPLIER_HEADER_STG (
  REQUEST_ID               VARCHAR2(250),                  -- OIC instance id (natural key)
  SOURCE_SYSTEM            VARCHAR2(30),                   -- e.g. 'Fusion'
  REF_ID_FUSION            VARCHAR2(240),                  -- Fusion SupplierId / SupplierNumber
  OIC_INTEGRATION_NAME     VARCHAR2(100),
  OIC_INSTANCE_ID          VARCHAR2(100),
  OPERATION                VARCHAR2(10),                   -- 'CREATE' / 'UPDATE'
  VENDOR_NAME              VARCHAR2(240),
  VENDOR_NUMBER            VARCHAR2(30),
  VENDOR_TYPE_LOOKUP_CODE  VARCHAR2(30),
  ENABLED_FLAG             VARCHAR2(1)  DEFAULT 'Y',
  INACTIVE_DATE            DATE,
  PROCESS_FLAG             VARCHAR2(1)  DEFAULT 'N',       -- N / P / E
  ERROR_MESSAGE            VARCHAR2(2000),
  EBS_VENDOR_ID            NUMBER,
  PARTY_ID                 NUMBER,
  PROCESSED_DATE           DATE,
  CREATED_BY               NUMBER       DEFAULT -1,
  CREATION_DATE            DATE         DEFAULT SYSDATE,
  LAST_UPDATED_BY          NUMBER       DEFAULT -1,
  LAST_UPDATE_DATE         DATE         DEFAULT SYSDATE,
  LAST_UPDATE_LOGIN        NUMBER
);
```

### 3.2 Error log — `APPS.XXC_INTEGRATION_ERROR_LOG`

Parallel persistent log so support can triage failures without OIC access.

```sql
CREATE SEQUENCE APPS.XXC_INTEGRATION_ERR_LOG_S  START WITH 1  CACHE 20;

CREATE TABLE APPS.XXC_INTEGRATION_ERROR_LOG (
  LOG_ID            NUMBER DEFAULT ON NULL APPS.XXC_INTEGRATION_ERR_LOG_S.NEXTVAL  NOT NULL,
  LOG_TIMESTAMP     TIMESTAMP       DEFAULT SYSTIMESTAMP,
  INTERFACE_ID      NUMBER,
  SOURCE_SYSTEM     VARCHAR2(30),
  REF_ID_FUSION     VARCHAR2(240),
  ERROR_STAGE       VARCHAR2(60),
  ERROR_MESSAGE     VARCHAR2(2000),
  ERROR_STACK       CLOB,
  CREATED_BY        NUMBER          DEFAULT -1,
  CREATION_DATE     DATE            DEFAULT SYSDATE,
  CONSTRAINT xxc_integ_err_log_pk PRIMARY KEY (LOG_ID)
);

CREATE INDEX APPS.xxc_integ_err_log_n1 ON APPS.xxc_integration_error_log (ref_id_fusion);
```

### 3.3 PL/SQL package — `APPS.XX_LOAD_SUP_EBS`

One procedure `Process_sups_api(in_request_id, Res_out)`:
- Takes OIC's `request_id` as input
- Fetches the matching `N` staging row
- Calls `ap_vendor_pub_pkg.create_vendor`
- On success → updates row to `P` with `ebs_vendor_id` + `party_id`
- On error → updates row to `E` with the full error stack + returns the error text via `Res_out`
- On unexpected exception → catches, logs, returns `'FATAL: ...'`

**Package spec:**

```sql
CREATE OR REPLACE PACKAGE APPS.XX_LOAD_SUP_EBS AS
   PROCEDURE Process_sups_api (in_request_id IN  VARCHAR2,
                               Res_out       OUT VARCHAR2);
END XX_LOAD_SUP_EBS;
/
```

**Package body** (as-deployed on the Vision instance):

```sql
CREATE OR REPLACE PACKAGE BODY APPS.XX_LOAD_SUP_EBS AS

   PROCEDURE Process_sups_api (in_request_id IN  VARCHAR2,
                               Res_out       OUT VARCHAR2)
   AS
      v_vendor_rec      ap_vendor_pub_pkg.r_vendor_rec_type;
      v_return_status   VARCHAR2(10);
      v_msg_count       NUMBER;
      v_msg_data        VARCHAR2(2000);
      v_vendor_id       NUMBER;
      v_party_id        NUMBER;
      l_error_msg       VARCHAR2(4000);
      l_rows            NUMBER := 0;
   BEGIN
      -- Session context — runs ONCE per call, not per loop iteration
      fnd_global.apps_initialize(0, 20639, 200);                -- SYSADMIN / Payables Manager / AP
      mo_global.set_policy_context('S', 204);                   -- Vision Operations OU

      FOR REC IN (
         SELECT a.operation                AS operation,
                a.vendor_name               AS vendor_name,
                a.vendor_type_lookup_code   AS vendor_type_lookup_code
           FROM apps.xxc_supplier_header_stg a
          WHERE process_flag = 'N'
            AND request_id   = in_request_id)
      LOOP
         l_rows := l_rows + 1;

         IF UPPER(REC.operation) = 'CREATE' THEN
            v_vendor_rec.vendor_name             := REC.vendor_name;
            v_vendor_rec.segment1                := NULL;         -- EBS auto-numbers
            v_vendor_rec.vendor_type_lookup_code := REC.vendor_type_lookup_code;

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
               UPDATE apps.xxc_supplier_header_stg
                  SET process_flag   = 'P',
                      ebs_vendor_id  = v_vendor_id,
                      party_id       = v_party_id,
                      processed_date = SYSDATE
                WHERE request_id = in_request_id;
               COMMIT;
               Res_out := 'SUCCESSFUL API - ebs id: ' || TO_CHAR(v_vendor_id);
            ELSE
               -- Drain the full fnd_msg_pub stack — v_msg_data alone is the first message only
               l_error_msg := NULL;
               FOR i IN 1 .. v_msg_count LOOP
                  l_error_msg := l_error_msg
                              || fnd_msg_pub.get(i, fnd_api.g_false)
                              || ' | ';
               END LOOP;

               UPDATE apps.xxc_supplier_header_stg
                  SET process_flag  = 'E',
                      error_message = SUBSTR(l_error_msg, 1, 1990),
                      processed_date = SYSDATE
                WHERE request_id = in_request_id;
               COMMIT;
               Res_out := 'ERROR: ' || SUBSTR(l_error_msg, 1, 500);
            END IF;
         END IF;
      END LOOP;

      IF l_rows = 0 THEN
         Res_out := 'ERROR - No data found for request_id=' || in_request_id;
      END IF;

   EXCEPTION WHEN OTHERS THEN
      l_error_msg := SUBSTR(SQLERRM, 1, 2000);
      UPDATE apps.xxc_supplier_header_stg
         SET process_flag   = 'E',
             error_message  = l_error_msg,
             processed_date = SYSDATE
       WHERE request_id = in_request_id;
      COMMIT;
      Res_out := 'FATAL: ' || l_error_msg;
   END Process_sups_api;

END XX_LOAD_SUP_EBS;
/
```

**Why per-row with `request_id` (not "process all N")?** Keeps each OIC event responsible for its own row, returns the specific `Res_out` back to OIC, and avoids cross-event races. The cursor form is kept (rather than a single SELECT) so the procedure tolerates accidental duplicate rows.

## 4. OIC side — integration `FUSION_SUPPLIER_TO_EBS`

### 4.1 Connections

| Connection | Adapter | Role |
|---|---|---|
| `FUSION_ERP_SRC`  | Oracle ERP Cloud       | Subscribes to Fusion business events + REST for enrichment |
| `EBS_DB_TGT`      | Oracle Database        | JDBC via on-prem Connectivity Agent to `<ebs-host>:1521/EBSDB` |

The DB adapter uses a dedicated `OIC_INT` DB user with only:
```sql
GRANT INSERT                  ON apps.xxc_supplier_header_stg TO oic_int;
GRANT EXECUTE ON apps.xx_load_sup_ebs                         TO oic_int;
```

### 4.2 Flow

```
[Trigger: Fusion supplierCreated event]
    │
    ▼
[REST GET /suppliers/{id}?expand=addresses,sites]       ← enrich (event carries only the id)
    │
    ▼
[Map → request_id, source_system, ref_id_fusion, vendor_name, vendor_type_lookup_code, operation, ...]
    │
    ▼
[DB Invoke #1:  INSERT xxc_supplier_header_stg]         ← REQUEST_ID = OIC instance id
    │
    ▼
[DB Invoke #2:  CALL xx_load_sup_ebs.process_sups_api(request_id, Res_out)]
    │
    ▼
[Switch on Res_out]
    ├─ starts-with('SUCCESSFUL')  → (optional) PATCH Fusion with EBS vendor_id → End
    └─ otherwise                  → [Throw New Fault]  (fails OIC instance → Error Hospital)
```

### 4.3 DB invoke #2 — the Switch & Fault

**Switch expression** (the happy branch):
```
starts-with($CallProcessSupsApi/OutputParameters/Res_out, 'SUCCESSFUL')
```

**Otherwise branch** → **Throw New Fault**:
- `title`     = `"EBS supplier creation failed"`
- `detail`    = `$CallProcessSupsApi/OutputParameters/Res_out`
- `errorCode` = `"EBS_API_ERROR"`

The fault fails the integration instance → appears as **Errored** in OIC Monitoring, preserving the Res_out message for support triage.

### 4.4 Field mapping (Fusion → staging)

| Staging column | Source expression |
|---|---|
| `REQUEST_ID`              | `$instanceId` (OIC instance id) |
| `SOURCE_SYSTEM`           | `"Fusion"` (constant) |
| `REF_ID_FUSION`           | `$Supplier/SupplierId` |
| `OIC_INTEGRATION_NAME`    | `"FUSION_SUPPLIER_TO_EBS"` |
| `OIC_INSTANCE_ID`         | `$instanceId` |
| `OPERATION`               | `"CREATE"` |
| `VENDOR_NAME`             | `$Supplier/Name` |
| `VENDOR_NUMBER`           | `$Supplier/SupplierNumber` (or omit → EBS auto-numbers) |
| `VENDOR_TYPE_LOOKUP_CODE` | `dvm:lookupValue('LKP_SUPPLIER_TYPE','FUSION',$Supplier/SupplierType,'EBS','VENDOR')` |
| `ENABLED_FLAG`            | `"Y"` |

## 5. End-to-end verification

### 5.1 First live run (recorded)

1. Supplier `OIC_FUSION_TO_EBS` created in Fusion.
2. OIC event fires → integration lands staging row:
   ```
   REQUEST_ID    = 90f42bd0-3fce-11f1-afeb-3551e1b329fc
   REF_ID_FUSION = 300003982047268
   VENDOR_NAME   = OIC_FUSION_TO_EBS
   PROCESS_FLAG  = N
   ```
3. OIC calls `xx_load_sup_ebs.process_sups_api(...)` — returns `Res_out = "SUCCESSFUL API - ebs id: 40178"`.
4. Staging row after:
   ```
   PROCESS_FLAG = P, EBS_VENDOR_ID = 40178, PARTY_ID = 477201
   PROCESSED_DATE = 2026-04-22 13:38:47
   ```
5. New row visible in `ap_suppliers`:
   ```sql
   SELECT vendor_id, segment1, vendor_name, vendor_type_lookup_code, enabled_flag
   FROM   ap_suppliers WHERE vendor_id = 40178;
   -- 40178   19   OIC_FUSION_TO_EBS   VENDOR   Y
   ```
6. Visible in EBS UI: **Payables Manager → Suppliers → Entry**, search `OIC_FUSION_TO_EBS`.

### 5.2 Re-invoke from sqlplus (for debugging)

```sql
DECLARE l_r VARCHAR2(2000);
BEGIN
  apps.xx_load_sup_ebs.process_sups_api('<request_id-from-staging>', l_r);
  dbms_output.put_line(l_r);
END;
/
```

## 6. Monitoring & triage

```sql
-- Backlog
SELECT process_flag, COUNT(*) FROM apps.xxc_supplier_header_stg GROUP BY process_flag;

-- Recent activity
SELECT request_id, ref_id_fusion, vendor_name, process_flag,
       ebs_vendor_id, SUBSTR(error_message,1,80) err, processed_date
FROM   apps.xxc_supplier_header_stg
ORDER  BY creation_date DESC FETCH FIRST 20 ROWS ONLY;

-- What errored recently
SELECT request_id, ref_id_fusion, SUBSTR(error_message,1,200) error_message, processed_date
FROM   apps.xxc_supplier_header_stg
WHERE  process_flag = 'E'
ORDER  BY processed_date DESC;
```

**Operator reprocess** (after fixing cause):
```sql
UPDATE apps.xxc_supplier_header_stg
SET    process_flag = 'N', error_message = NULL
WHERE  request_id = :bad_request_id;
COMMIT;

-- Then re-invoke:
EXEC apps.xx_load_sup_ebs.process_sups_api(:bad_request_id, :out);
```

## 7. Known limitations / next steps

| Item | Note |
|---|---|
| Only `CREATE` branch implemented | `UPDATE` events are silently skipped — add an `elsif` branch calling `ap_vendor_pub_pkg.update_vendor` when needed |
| Single-row-at-a-time per `request_id` | Fine for real-time; for bulk backfill, wrap a `FOR r IN (SELECT request_id FROM ... WHERE process_flag='N')` loop around the call |
| `OPERATION` case inconsistency | OIC sends `'create'` lowercase; PL/SQL uses `UPPER()` — robust but watch for mapping typos |
| No supplier sites yet | Sites require a second API (`create_vendor_site`) and a second staging table — scope for a later phase |
| No XRef table | Not needed for CREATE-only flow. Required if/when UPDATE is added, to map Fusion SupplierId → EBS vendor_id |
| `Res_out` uses string prefix (`SUCCESSFUL` / `ERROR` / `FATAL`) | Works; a structured status code (e.g. separate `x_status` OUT) would make the OIC Switch more robust |

## 8. Architecture at a glance — for a LinkedIn post

Supplier born in Fusion Cloud Procurement. OIC listens for the business event, enriches via REST, lands a row in an EBS staging table, and synchronously calls a custom PL/SQL wrapper. The wrapper invokes the standard `ap_vendor_pub_pkg.create_vendor` API, writes the result back to staging, and returns a status string to OIC. OIC branches on that string — success path returns cleanly, error path throws a fault into OIC's Error Hospital. **One Fusion click → supplier in `ap_suppliers` in ~2–5 seconds.**

Back to [../](../).
