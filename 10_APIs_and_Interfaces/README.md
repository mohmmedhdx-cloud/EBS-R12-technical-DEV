# 10 — APIs and Open Interfaces

## What it is
Two supported ways to push data *into* EBS:

- **Public APIs** (`*_API`, `*_PUB`, `*_PVT` packages) — row‑at‑a‑time validated calls, real-time. Examples: `HR_EMPLOYEE_API`, `FND_USER_PKG`, `AP_INVOICES_PKG`, `OE_ORDER_PUB`.
- **Open Interface tables** — bulk load a staging table, then run a seeded "Import" concurrent program that validates and moves rows into base tables. Examples: `GL_INTERFACE` → Journal Import, `AP_INVOICES_INTERFACE` → Payables Open Interface Import, `RA_INTERFACE_LINES_ALL` → AutoInvoice.

Rule of thumb: **never `INSERT` directly into seeded base tables** — always go through an API or an interface.

## How to use

### A) Public API
1. Check Oracle's *Integration Repository* (irep) for the signature and mandatory parameters.
2. Initialize EBS context with `fnd_global.apps_initialize`.
3. Call the API; check the `x_return_status` / `errbuf` out variables; `COMMIT` on success, `ROLLBACK` on failure.

### B) Open Interface
1. Insert rows into the interface table (per Oracle's docs for required columns).
2. Submit the import concurrent program.
3. Review error rows (rejected) and reprocess.

## Sample

### A) Create an employee with `hr_employee_api`

```plsql
DECLARE
    l_employee_number   per_all_people_f.employee_number%TYPE;
    l_person_id         NUMBER;
    l_assignment_id     NUMBER;
    l_per_object_version_number NUMBER;
    l_asg_object_version_number NUMBER;
    l_effective_start_date DATE;
    l_effective_end_date   DATE;
    l_full_name            VARCHAR2(240);
    l_per_effective_start_date DATE;
    l_per_effective_end_date   DATE;
    l_assign_payroll_warning BOOLEAN;
    l_orig_hire_warning      BOOLEAN;
BEGIN
    fnd_global.apps_initialize(user_id=>1318, resp_id=>50559, resp_appl_id=>800);

    hr_employee_api.create_employee(
        p_hire_date                    => SYSDATE,
        p_business_group_id            => 202,
        p_last_name                    => 'DOE',
        p_first_name                   => 'JOHN',
        p_sex                          => 'M',
        p_date_of_birth                => TO_DATE('1990-05-12','YYYY-MM-DD'),
        p_employee_number              => l_employee_number,
        p_person_id                    => l_person_id,
        p_assignment_id                => l_assignment_id,
        p_per_object_version_number    => l_per_object_version_number,
        p_asg_object_version_number    => l_asg_object_version_number,
        p_per_effective_start_date     => l_per_effective_start_date,
        p_per_effective_end_date       => l_per_effective_end_date,
        p_full_name                    => l_full_name,
        p_assign_payroll_warning       => l_assign_payroll_warning,
        p_orig_hire_warning            => l_orig_hire_warning
    );
    COMMIT;
    DBMS_OUTPUT.put_line('Emp # ' || l_employee_number);
END;
/
```

### B) Feed `GL_INTERFACE` and launch Journal Import

```plsql
INSERT INTO gl_interface (
    status, set_of_books_id, accounting_date, currency_code,
    date_created, created_by, actual_flag,
    user_je_category_name, user_je_source_name,
    segment1, segment2, segment3, segment4, segment5,
    entered_dr, entered_cr, reference1, group_id
) VALUES (
    'NEW', 1, TRUNC(SYSDATE), 'USD',
    SYSDATE, fnd_global.user_id, 'A',
    'Adjustment', 'Manual',
    '01','000','1100','0000','000',
    100, 0, 'XXC-LOAD-001', 9001
);
COMMIT;

-- Then submit the "Journal Import" program (short name GLLEZL) from
-- GL Super User → View → Requests → Submit, OR via fnd_request.submit_request.
```

## Next commands
- Expanded list of the 20 most-used APIs and interface tables by module.
- Error handling pattern: capture `GL_INTERFACE_CONTROL` + `GL_INTERFACE` rejects.
- How to find an API: Integration Repository + `fnd_objects_vl`.
