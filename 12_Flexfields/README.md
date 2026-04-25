# 12 — Flexfields

## What it is
Flexfields are EBS's metadata‑driven way to add extensible, validated fields to seeded tables without DDL changes.

Two kinds:
- **Key Flexfield (KFF)** — represents a compound key made of segments, each validated from a value set. Example: GL **Accounting Flexfield** (`GL_CODE_COMBINATIONS`), Inventory **System Items** (`MTL_SYSTEM_ITEMS_B`), **Asset Key**.
- **Descriptive Flexfield (DFF)** — optional extra columns (`ATTRIBUTE1` .. `ATTRIBUTE30`) already present on most seeded tables. You switch them on and define segments that show on the form.

Context sensitivity: a DFF can show different segments depending on a reference field (e.g. Supplier Type = "DOMESTIC" vs "IMPORT").

## How to use

### Enable a Descriptive Flexfield
Responsibility **Application Developer**:

1. **Flexfield → Descriptive → Segments**.
2. Query the DFF (e.g. *Application = Payables, Title = "Invoice Header DFF"*).
3. Uncheck **Freeze Flexfield Definition** and **Compile**.
4. Add segments: Name, Column (`ATTRIBUTE1`..), Value Set, Prompt, Required, Displayed.
5. Optional: define a **Context Field** + **Context-Sensitive** segments.
6. Re‑check **Freeze** and **Compile**.
7. Bounce the form's cache (close/reopen) — segments now appear as `[ ]` brackets on the form.

### Register a custom DFF on your own table
If you want a DFF on `xxc_my_table`:

1. Add 30 attribute columns: `attribute_category VARCHAR2(30)`, `attribute1..attribute30 VARCHAR2(150)`.
2. **Application Developer → Flexfield → Descriptive → Register** — register the table with columns.
3. **Flexfield → Descriptive → Segments** — define segments as above.

## Sample

Register a DFF column set on a custom table:

```sql
-- Add the columns
ALTER TABLE xxc_proj_tasks
  ADD (attribute_category VARCHAR2(30),
       attribute1         VARCHAR2(150),
       attribute2         VARCHAR2(150),
       attribute3         VARCHAR2(150));
```

```plsql
-- Register the table (programmatic equivalent of the Register screen)
BEGIN
    fnd_descr_flex_col_usage_api.register_flexfield_table(
        p_application_short_name => 'XXC',
        p_table_name             => 'XXC_PROJ_TASKS',
        p_user_table_name        => 'Project Tasks'
    );
END;
/
```

Validate a DFF value in PL/SQL:

```plsql
DECLARE
    l_valid BOOLEAN;
BEGIN
    l_valid := fnd_flex_descval.validate_desccols(
        appl_short_name => 'XXC',
        desc_flex_name  => 'XXC_PROJ_TASKS_DFF',
        values_or_ids   => 'V',
        validation_date => SYSDATE,
        values          => fnd_flex_descval.input_attributes(
                             'ATTRIBUTE_CATEGORY' => 'GLOBAL',
                             'ATTRIBUTE1'         => 'PHASE1'
                          )
    );
    DBMS_OUTPUT.put_line('valid = ' || CASE WHEN l_valid THEN 'Y' ELSE 'N' END);
END;
/
```

## Next commands
- Full KFF walk-through on the **Accounting Flexfield** (segments, qualifier, code combinations).
- Context-sensitive DFF with dependent value sets.
- Query flexfield metadata (`fnd_descriptive_flexs_vl`, `fnd_descr_flex_column_usages`).
