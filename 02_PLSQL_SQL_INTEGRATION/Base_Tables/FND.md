# FND — AOL / Security / Concurrent Processing Base Tables & Joins (SQL & PL/SQL for EBS)

Verified against the live Vision R12.2.12 instance.

FND tables are **global** — no `ORG_ID`, no MOAC required. They live in the `APPLSYS` schema with APPS synonyms.

## Tables

### Security chain (User → Responsibility → Menu → Function)

| Table | Purpose |
|---|---|
| `FND_USER` | User master (`user_name`, `email`, start/end dates, password expiry) |
| `FND_RESPONSIBILITY` | Responsibility master |
| `FND_RESPONSIBILITY_VL` | Translated view with `responsibility_name` |
| `FND_USER_RESP_GROUPS_DIRECT` | **View** — explicit user→resp assignments |
| `FND_USER_RESP_GROUPS_INDIRECT` | **View** — inherited (role-based) assignments |
| `FND_USER_RESP_GROUPS` | **View** — union of direct + indirect |
| `FND_MENUS` | Menu master |
| `FND_MENUS_TL` | Translated menu names |
| `FND_MENU_ENTRIES` | Tree of menu entries (parent `menu_id` + `sub_menu_id` or `function_id`) |
| `FND_MENU_ENTRIES_TL` | Translated prompts |
| `FND_FORM_FUNCTIONS` | Function master (SSWA JSP / Forms / sub-function) |
| `FND_FORM_FUNCTIONS_TL` | Translated function names |
| `FND_DATA_GROUPS` | Data group master (maps logical applications → physical schemas) |

### Concurrent Processing

| Table | Purpose |
|---|---|
| `FND_CONCURRENT_PROGRAMS` | Concurrent program definition |
| `FND_CONCURRENT_PROGRAMS_VL` | Translated (adds `user_concurrent_program_name`) |
| `FND_EXECUTABLES` | Executable (points at actual physical code) |
| `FND_EXECUTABLES_VL` | Translated |
| `FND_CONCURRENT_REQUESTS` | Every submitted request — phase / status / request output path |
| `FND_REQUEST_GROUPS` | Request group master |
| `FND_REQUEST_GROUP_UNITS` | Mapping of programs / sets into request groups |
| `FND_APPLICATION` | Application master |
| `FND_APPLICATION_VL` | Translated |

### Lookups, Profiles, Currencies

| Table | Purpose |
|---|---|
| `FND_LOOKUP_TYPES` | Lookup type master |
| `FND_LOOKUP_VALUES` | Codes + meanings per lookup type + language |
| `FND_PROFILE_OPTIONS` | Profile option master |
| `FND_PROFILE_OPTION_VALUES` | Set values at SITE / APP / RESP / USER / ORG / SERVER level |
| `FND_CURRENCIES` | Currency master |
| `FND_LANGUAGES` | Language codes + enabled flag |

## Canonical joins (all verified)

### What a user can access — User → Responsibility → Menu → Function

```sql
SELECT fu.user_name,
       fr.responsibility_name,
       fm.menu_name,
       fmetl.prompt             AS menu_label,
       fff.function_name,
       fff.user_function_name
FROM   fnd_user                      fu
JOIN   fnd_user_resp_groups_direct   urg   ON urg.user_id          = fu.user_id
JOIN   fnd_responsibility_vl         fr    ON fr.responsibility_id = urg.responsibility_id
JOIN   fnd_menus                     fm    ON fm.menu_id           = fr.menu_id
JOIN   fnd_menu_entries              fme   ON fme.menu_id          = fm.menu_id
LEFT JOIN fnd_menu_entries_tl        fmetl ON fmetl.menu_id        = fme.menu_id
                                          AND fmetl.entry_sequence = fme.entry_sequence
                                          AND fmetl.language       = USERENV('LANG')
JOIN   fnd_form_functions_vl         fff   ON fff.function_id      = fme.function_id
WHERE  fu.user_name = 'OPERATIONS'
AND    SYSDATE BETWEEN NVL(fu.start_date,SYSDATE-1)    AND NVL(fu.end_date,     SYSDATE+1)
AND    SYSDATE BETWEEN NVL(urg.start_date,SYSDATE-1)   AND NVL(urg.end_date,    SYSDATE+1)
AND    SYSDATE BETWEEN NVL(fr.start_date,SYSDATE-1)    AND NVL(fr.end_date,     SYSDATE+1)
ORDER  BY fr.responsibility_name, fme.entry_sequence;
```

### Concurrent request → Program → Executable

```sql
SELECT fcr.request_id,
       fcpv.user_concurrent_program_name,
       fev.executable_name,
       fev.execution_method_code,
       fcr.phase_code,
       fcr.status_code,
       fcr.actual_start_date,
       fcr.actual_completion_date,
       fu.user_name           AS submitted_by
FROM   fnd_concurrent_requests   fcr
JOIN   fnd_concurrent_programs_vl fcpv
       ON fcpv.concurrent_program_id = fcr.concurrent_program_id
      AND fcpv.application_id        = fcr.program_application_id
JOIN   fnd_executables_vl        fev
       ON fev.executable_id          = fcpv.executable_id
JOIN   fnd_user                  fu  ON fu.user_id = fcr.requested_by
WHERE  fcr.request_date >= TRUNC(SYSDATE) - 1
ORDER  BY fcr.request_date DESC;
```

### Lookup type + values

```sql
SELECT lt.lookup_type,
       ltt.meaning       AS type_meaning,
       lv.lookup_code,
       lv.meaning        AS value_meaning,
       lv.enabled_flag,
       lv.start_date_active,
       lv.end_date_active
FROM   fnd_lookup_types        lt
JOIN   fnd_lookup_types_tl     ltt ON ltt.lookup_type = lt.lookup_type
                                  AND ltt.language    = USERENV('LANG')
JOIN   fnd_lookup_values       lv  ON lv.lookup_type  = lt.lookup_type
                                  AND lv.language     = USERENV('LANG')
WHERE  lt.lookup_type = 'YES_NO';
```

### Profile option + all set values at every level

```sql
SELECT fpot.user_profile_option_name,
       DECODE(fpov.level_id,
              10001,'Site',
              10002,'App',
              10003,'Resp',
              10004,'User',
              10005,'Server',
              10006,'Org')    AS level_name,
       fpov.level_value,
       fpov.profile_option_value
FROM   fnd_profile_options         fpo
JOIN   fnd_profile_options_tl      fpot ON fpot.profile_option_name = fpo.profile_option_name
                                       AND fpot.language            = USERENV('LANG')
LEFT JOIN fnd_profile_option_values fpov ON fpov.profile_option_id = fpo.profile_option_id
WHERE  fpo.profile_option_name = 'GL_SET_OF_BKS_ID'
ORDER  BY fpov.level_id;
```

### Request Group contents (what a responsibility can submit)

```sql
SELECT fr.responsibility_name,
       frg.request_group_name,
       fcpv.user_concurrent_program_name,
       frgu.request_unit_type
FROM   fnd_responsibility_vl     fr
JOIN   fnd_request_groups        frg  ON frg.request_group_id = fr.request_group_id
JOIN   fnd_request_group_units   frgu ON frgu.request_group_id = frg.request_group_id
JOIN   fnd_concurrent_programs_vl fcpv ON fcpv.concurrent_program_id = frgu.request_unit_id
                                       AND fcpv.application_id        = frgu.unit_application_id
WHERE  fr.responsibility_key = 'SYSTEM_ADMINISTRATOR';
```

## Useful lookup IDs for filters

| Filter | Column / value |
|---|---|
| Active user | `fnd_user.end_date IS NULL OR fnd_user.end_date > SYSDATE` |
| Open concurrent request | `fnd_concurrent_requests.phase_code = 'R'` (Running) or `'P'` (Pending) |
| Completed request | `phase_code = 'C'` — status_code = `'C'` (Normal), `'G'` (Warning), `'E'` (Error), `'D'` (Cancelled), `'X'` (Terminated) |

## Next

Back to [../Base_Tables/](../Base_Tables/).
