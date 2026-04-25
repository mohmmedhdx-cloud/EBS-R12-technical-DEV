# 08 — Forms Personalization

## What it is
EBS R12 still uses classic **Oracle Forms** for many transactional screens (GL Journals, PO, AP Invoices, HR Forms). **Forms Personalization** lets you change their behavior (hide fields, default values, call PL/SQL, show messages, enforce rules) at runtime — stored as rules in `FND_FORM_CUSTOM_RULES` — **without recompiling the `.fmb` file**.

Like OAF personalization, it's patch‑safe.

## How to use
1. Grant your responsibility the ability to use it — profile option **Utilities:Diagnostics = Yes** and **Hide Diagnostics menu entry = No** at user level.
2. Open the target form (e.g. *People → Enter and Maintain*).
3. Menu **Help → Diagnostics → Custom Code → Personalize**.
4. Add a rule row:
   - **Description** — what you're doing.
   - **Trigger Event** — `WHEN-NEW-FORM-INSTANCE`, `WHEN-VALIDATE-RECORD`, `WHEN-NEW-ITEM-INSTANCE`, etc.
   - **Condition** — optional SQL/PLSQL boolean.
   - **Actions** — Property, Message, Builtin, Menu, Special, or Property=Execute Query.
5. Save → close and re‑open the form → rule fires.

Rules are stored in `FND_FORM_CUSTOM_RULES` / `FND_FORM_CUSTOM_ACTIONS` and can be migrated via **FNDLOAD** with `afsload.lct`.

## Sample — enforce a dept-id min value on People form

| Field | Value |
|---|---|
| Seq | 10 |
| Description | Warn if Employee Number < 1000 |
| Level | Responsibility → *XXC HR Manager* |
| Trigger Event | `WHEN-VALIDATE-RECORD` |
| Trigger Object | `PEOPLE` (block) |
| Condition | `:PEOPLE.EMPLOYEE_NUMBER IS NOT NULL AND TO_NUMBER(:PEOPLE.EMPLOYEE_NUMBER) < 1000` |
| Action type | **Message** |
| Message type | Show |
| Message text | `Employee numbers below 1000 are reserved for legacy records.` |

**Migrate it with FNDLOAD:**

```bash
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/afsload.lct \
    xxc_people_form_pers.ldt FND_FORM_CUSTOM_RULES \
    FUNCTION_NAME='PERWSHRG'
```

## Next commands
- Ten most common trigger events and when to use each.
- Calling a custom PL/SQL package from a rule (Builtin → `FND_UTILITIES.OPEN_URL`, `EXECUTE_PROCEDURE`).
- Rule ordering, conditions, and debugging via **Help → Diagnostics → Examine**.
