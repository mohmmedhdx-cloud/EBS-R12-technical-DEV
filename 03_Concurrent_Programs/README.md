# 03 — Concurrent Programs

## What it is
A **Concurrent Program** is how EBS runs batch jobs (reports, data loads, interfaces). It's defined in AOL and submitted to the Concurrent Manager, which runs it on the Apps tier and captures a log + output file.

Every concurrent program has three pieces in AOL:
- **Executable** — points at the physical code (PL/SQL procedure, host script, Java, BIP, SQL*Plus, Oracle Report, etc.).
- **Program** — the user‑visible registration (short name, parameters, output format, style).
- **Parameters / Value Set** — input prompts shown when the user submits the program.

The program is then attached to a **Request Group** so a responsibility can see it.

## How to use
Navigator (Responsibility **System Administrator** or **Application Developer**):

1. **Concurrent → Program → Executable** — create the executable, give it a short name and execution method (e.g. *PL/SQL Stored Procedure*), and point at `XXC_EMP_UTIL_PKG.LOG_ACTIVE_EMPLOYEES`.
2. **Concurrent → Program → Define** — create the program, link the executable, set output type (Text / XML / PDF), and add parameters.
3. Define any **Value Sets** (*Application Developer → Validation → Set*) needed by parameters.
4. **Security → Responsibility → Request** — add the program to the responsibility's request group.
5. **View → Requests → Submit a New Request** to run it.

From PL/SQL you can submit it programmatically:

## Sample

```plsql
DECLARE
    l_request_id NUMBER;
BEGIN
    -- Required context
    fnd_global.apps_initialize(
        user_id      => 1318,   -- FND_USER.USER_ID
        resp_id      => 50559,  -- FND_RESPONSIBILITY.RESPONSIBILITY_ID
        resp_appl_id => 800     -- HR
    );

    l_request_id := fnd_request.submit_request(
        application => 'XXC',                          -- app short name
        program     => 'XXC_EMP_LOG',                  -- program short name
        description => 'Active employees by dept',
        start_time  => SYSDATE,
        sub_request => FALSE,
        argument1   => '101'                           -- p_department_id
    );

    COMMIT;
    DBMS_OUTPUT.put_line('Submitted request_id = ' || l_request_id);
END;
/
```

Monitor: **View → Requests → Find** → request id.

## Next commands
- Full walk‑through of creating a value set (Independent, Table, Special) with screenshots.
- Add a Host ($XXC_TOP/bin/) executable example (shell script + `$FCP_LOGIN`, `$FCP_USERID`).
- Chaining: request sets, incompatibilities, and sub‑requests.
