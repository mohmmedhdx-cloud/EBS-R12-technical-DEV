# 05 — WebADI (Web Applications Desktop Integrator)

## What it is
WebADI lets users download an Excel spreadsheet from EBS, enter/edit data offline, and upload it back into EBS through a validated interface. It's the standard tool for bulk data entry (journals, budgets, items, BOMs, custom uploads).

Underlying objects live in the **BNE** schema: `BNE_INTEGRATORS_B`, `BNE_LAYOUTS_B`, `BNE_MAPPINGS_B`, `BNE_CONTENTS_B`.

## How to use
Responsibility **Desktop Integration Manager** (or define one):

1. **Create an Integrator** — *Create Document → Integrator → Create* — choose the application, name, and import type (API, Interface Table, or PL/SQL package).
2. **Define the Interface** — columns coming from your staging table or API parameters.
3. **Define a Layout** — which columns appear in Excel, field order, header labels, LOVs.
4. **Define a Mapping** — map Excel columns → interface columns.
5. **Define Content** (optional) — pre‑populate the spreadsheet from a SQL query.
6. Attach the Integrator to a **Form Function**, add it to a **Menu** and a **Responsibility**.
7. End user: *Navigator → Create Document →* select integrator → Excel opens → fill rows → *Add-Ins → Oracle → Upload*.

## Sample — custom integrator calling a PL/SQL API

Staging table + upload API:

```plsql
CREATE TABLE xxc_emp_upload_stg (
    emp_number      VARCHAR2(30),
    full_name       VARCHAR2(240),
    department_id   NUMBER,
    upload_date     DATE DEFAULT SYSDATE,
    status          VARCHAR2(1)  DEFAULT 'N',
    error_message   VARCHAR2(500)
);

CREATE OR REPLACE PROCEDURE xxc_emp_webadi_upload (
    p_emp_number    IN VARCHAR2,
    p_full_name     IN VARCHAR2,
    p_department_id IN NUMBER
) IS
BEGIN
    INSERT INTO xxc_emp_upload_stg (emp_number, full_name, department_id)
    VALUES (p_emp_number, p_full_name, p_department_id);
END;
/
```

In Integrator setup:
- **Import type**: PL/SQL API — `xxc_emp_webadi_upload`.
- **Interface attributes**: `P_EMP_NUMBER` (VARCHAR2), `P_FULL_NAME` (VARCHAR2), `P_DEPARTMENT_ID` (NUMBER).
- **Layout**: include all three columns, mark `P_EMP_NUMBER` required.
- **Mapping**: auto-map 1:1.

## Next commands
- Full walk‑through with screenshots of the Desktop Integration Manager screens.
- Add Excel LOVs driven by SQL (Define List of Values step).
- Troubleshoot the common "Create Document fails with BNE-XXXXX" errors.
