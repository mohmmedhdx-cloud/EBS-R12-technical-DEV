# 13 — Lookups

## What it is
**Lookups** are the standard way EBS stores small, code+meaning reference lists — like reason codes, yes/no flags, status values, document types. All lookups live in `FND_LOOKUP_VALUES` keyed by `LOOKUP_TYPE`.

Three access types:
- **User** — end users can extend the values.
- **Extensible** — Oracle ships seeded values, users may add more.
- **System** — locked, only Oracle can edit (e.g. `YES_NO`).

## How to use
Responsibility **Application Developer**:

1. **Application → Lookups → Application Object Library** (or the module‑specific one, e.g. *Payables Lookups*).
2. Enter a new **Lookup Type** (short code, e.g. `XXC_RISK_LEVEL`) + meaning + description.
3. Set **Access Level** (User / Extensible / System).
4. Add lookup **Code / Meaning / Description / Enabled / Effective dates** rows.
5. Save — immediately queryable via `FND_LOOKUP_VALUES_VL`.

In a form/page, use a **Lookup Value Set** (Validation → Set, type=*Special*, format=*Char*, validation=*Table* with query against `FND_LOOKUP_VALUES`), or reference the lookup directly in OAF via *Lookup Code* + *Lookup Type* item properties.

## Sample

Create a lookup programmatically:

```plsql
BEGIN
    fnd_lookups_pkg.insert_row(
        x_rowid             => NULL,
        x_lookup_type       => 'XXC_RISK_LEVEL',
        x_security_group_id => 0,
        x_view_application_id => 0,
        x_application_id    => 20003,              -- your custom app id
        x_customization_level => 'U',              -- User
        x_lookup_code       => 'LOW',
        x_meaning           => 'Low',
        x_description       => 'Low risk',
        x_enabled_flag      => 'Y',
        x_start_date_active => TO_DATE('2024-01-01','YYYY-MM-DD'),
        x_end_date_active   => NULL,
        x_created_by        => fnd_global.user_id,
        x_creation_date     => SYSDATE,
        x_last_updated_by   => fnd_global.user_id,
        x_last_update_date  => SYSDATE,
        x_last_update_login => fnd_global.login_id
    );
    COMMIT;
END;
/
```

LOV query pattern (usable in an OAF VO, a report, or a value set):

```sql
SELECT lookup_code, meaning, description
FROM   fnd_lookup_values_vl
WHERE  lookup_type = 'XXC_RISK_LEVEL'
AND    enabled_flag = 'Y'
AND    TRUNC(SYSDATE) BETWEEN NVL(start_date_active, TRUNC(SYSDATE))
                      AND     NVL(end_date_active,   TRUNC(SYSDATE))
ORDER  BY meaning;
```

## Next commands
- Migrate a lookup type with FNDLOAD (`aflvmlu.lct`).
- Lookup-backed value sets vs table-validated value sets — when to pick which.
- Multi-language meanings via `FND_LOOKUP_VALUES_TL`.
