# 14 — Profile Options

## What it is
**Profile Options** are EBS's hierarchical setting system. A single profile (e.g. `GL Set of Books Name`, `MO: Operating Unit`, `FND: Debug Log Enabled`) can have a different value at each level — the lowest set level wins at runtime.

Hierarchy (lowest priority → highest priority override):
**Site → Application → Responsibility → User** (and in R12 also Server/Organization in some cases).

Metadata lives in `FND_PROFILE_OPTIONS`; values in `FND_PROFILE_OPTION_VALUES`.

## How to use

### Define a custom profile option
Responsibility **Application Developer**:

1. **Profile → Define** — enter:
   - Profile Name (internal, e.g. `XXC_DEFAULT_WAREHOUSE`)
   - User Profile Name (what users see)
   - Application
   - SQL Validation (optional) — a query to constrain entered values
   - Hierarchy levels: tick *Site / App / Resp / User* as you want them settable.
2. Save — it now shows in the **System Administrator → Profile → System** screen.

### Set a value
Responsibility **System Administrator**:

1. **Profile → System** — query by profile name.
2. Tick the level(s) you want to set, enter the value, Save.

### Read a value at runtime
Use `FND_PROFILE.VALUE` (PL/SQL), `#{OADBTransaction.getProfile('NAME')}` (OAF), or `:PROFILES.NAME` (Forms, read‑only).

## Sample

```plsql
DECLARE
    l_warehouse VARCHAR2(240);
    l_debug     VARCHAR2(10);
BEGIN
    -- Initialize context for the running user/responsibility
    fnd_global.apps_initialize(user_id=>1318, resp_id=>50559, resp_appl_id=>800);

    l_warehouse := fnd_profile.value('XXC_DEFAULT_WAREHOUSE');
    l_debug     := fnd_profile.value('FND_DEBUG_LOG_ENABLED');

    DBMS_OUTPUT.put_line('Warehouse = ' || l_warehouse);
    DBMS_OUTPUT.put_line('Debug     = ' || l_debug);

    -- Set a profile value programmatically at User level
    IF fnd_profile.save(
        x_name         => 'XXC_DEFAULT_WAREHOUSE',
        x_value        => 'M1',
        x_level_name   => 'USER',
        x_level_value  => fnd_global.user_id
    ) THEN
        COMMIT;
        DBMS_OUTPUT.put_line('Saved.');
    END IF;
END;
/
```

Direct query of all settings for a profile (useful for debugging level precedence):

```sql
SELECT fpo.profile_option_name AS internal_name,
       fpot.user_profile_option_name,
       DECODE(fpov.level_id, 10001,'Site',10002,'App',10003,'Resp',10004,'User',
                             10005,'Server',10006,'Org') AS lvl,
       fpov.profile_option_value,
       fpov.level_value
FROM   fnd_profile_options      fpo,
       fnd_profile_options_tl   fpot,
       fnd_profile_option_values fpov
WHERE  fpo.profile_option_id = fpot.profile_option_id
AND    fpo.profile_option_id = fpov.profile_option_id
AND    fpo.profile_option_name = 'XXC_DEFAULT_WAREHOUSE'
AND    fpot.language = USERENV('LANG')
ORDER  BY fpov.level_id;
```

## Next commands
- Top 25 EBS profile options every technical developer should know.
- FNDLOAD migration of profile option definitions (`afscprof.lct`).
- Difference between `fnd_profile.value` and `fnd_profile.value_specific` (level-specific read).
