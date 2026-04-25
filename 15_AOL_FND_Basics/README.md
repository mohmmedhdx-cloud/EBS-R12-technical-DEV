# 15 — AOL / FND Basics

## What it is
**AOL (Application Object Library)** is the EBS security + navigation backbone. Four objects chain together to decide what a user can do:

**User → Responsibility → Menu → Function**

- **User** (`FND_USER`) — the login identity.
- **Responsibility** (`FND_RESPONSIBILITY`) — a role; controls the navigator, data security (via **Data Group**), and request groups.
- **Menu** (`FND_MENUS` / `FND_MENU_ENTRIES`) — tree of entries, each pointing at a function or a sub‑menu.
- **Function** (`FND_FORM_FUNCTIONS`) — the thing that actually runs: a form, an OAF JSP call, or a sub‑function (permission-only, no UI).

Also often grouped under "AOL": request groups, data groups, flexfields, profile options, concurrent programs, lookups, messages.

## How to use

Responsibility **System Administrator** (unless noted):

1. **Security → Responsibility → Define** — create responsibility; pick *Data Group = Standard*, *Menu = XXC_MAIN_MENU*, *Request Group = XXC_ALL*.
2. **Application → Function** (Application Developer) — define Forms or SSWA JSP functions.
3. **Application → Menu** — build the tree; each entry links to a function or submenu.
4. **Security → User → Define** — create user, attach one or more responsibilities.
5. Log in as that user and confirm the navigator matches.

## Sample

Create a user + responsibility assignment programmatically:

```plsql
DECLARE
    l_user_id NUMBER;
BEGIN
    fnd_user_pkg.createuser(
        x_user_name         => 'JDOE',
        x_owner             => 'CUST',
        x_unencrypted_password => 'Welcome1',
        x_email_address     => 'jdoe@example.com',
        x_start_date        => SYSDATE
    );

    fnd_user_pkg.addresp(
        username       => 'JDOE',
        resp_app       => 'XXC',
        resp_key       => 'XXC_HR_MANAGER',
        security_group => 'STANDARD',
        description    => 'HR Manager access',
        start_date     => SYSDATE,
        end_date       => NULL
    );

    COMMIT;
END;
/
```

Query "what can user JDOE access?":

```sql
SELECT  fr.responsibility_name,
        fm.menu_name,
        fme.prompt          AS entry_label,
        fff.function_name,
        fff.user_function_name
FROM    fnd_user                  fu
JOIN    fnd_user_resp_groups_direct furg  ON furg.user_id = fu.user_id
JOIN    fnd_responsibility_vl     fr      ON fr.responsibility_id = furg.responsibility_id
JOIN    fnd_menus                 fm      ON fm.menu_id = fr.menu_id
JOIN    fnd_menu_entries_vl       fme     ON fme.menu_id = fm.menu_id
JOIN    fnd_form_functions_vl     fff     ON fff.function_id = fme.function_id
WHERE   fu.user_name = 'JDOE'
ORDER   BY fr.responsibility_name, fme.entry_sequence;
```

## Next commands
- Data Groups, Security Groups, and MOAC (Multi-Org Access Control).
- Request Groups vs Request Security Groups, and how *code=Request Set* interacts.
- FNDLOAD migration of User/Responsibility/Menu/Function.
