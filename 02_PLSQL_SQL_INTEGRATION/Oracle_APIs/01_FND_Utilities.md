# FND Utilities — the APIs you call in *every* EBS package

Verified against the live Vision R12.2.12 instance.

These five packages show up in almost every custom EBS program: initialise the user/resp context, read profile options, raise translated messages, log from concurrent programs, and submit child requests.

## APIs covered

| API | What it does |
|---|---|
| `fnd_global.apps_initialize(user_id, resp_id, resp_appl_id)` | Sets the APPS context for the current session — **every** HR/OM/AR/AP API needs this first |
| `fnd_profile.value('PROFILE_NAME')` | Reads a profile option's effective value given current context |
| `fnd_message.set_name / set_token / get` | Assembles a translated message from the AOL message dictionary |
| `fnd_file.put_line(FND_FILE.LOG | FND_FILE.OUTPUT, 'text')` | Writes to concurrent request log or output file |
| `fnd_request.submit_request(...)` | Submits a concurrent program and returns the new `request_id` |

## `fnd_global.apps_initialize` — MUST-call

Without this, HR/OM/AR/AP public APIs throw "cannot find current organization" / "invalid responsibility" errors.

```sql
-- Look up your identity values once per instance:
SELECT user_id                FROM fnd_user             WHERE user_name='SYSADMIN';              -- e.g. 0
SELECT responsibility_id,
       application_id
FROM   fnd_responsibility_vl
WHERE  responsibility_key='SYSTEM_ADMINISTRATOR';                                                -- e.g. 20420, 1
```

Then in every PL/SQL entry point:

```sql
BEGIN
  fnd_global.apps_initialize(user_id       => 0,
                             resp_id       => 20420,
                             resp_appl_id  => 1);
  -- now call your module APIs
END;
/
```

**Verified:** after init, `fnd_global.user_id = 0`, `fnd_global.resp_id = 20420`.

## `fnd_profile.value` — read profile option

```sql
SET SERVEROUTPUT ON
DECLARE
  v_sob VARCHAR2(200);
BEGIN
  fnd_global.apps_initialize(0, 20420, 1);
  v_sob := fnd_profile.value('GL_SET_OF_BKS_ID');
  dbms_output.put_line('Ledger: ' || v_sob);
END;
/
```

**Verified output on Vision:** `Ledger: 1`

Values resolve bottom-up: **User → Responsibility → Application → Site**. Change the user or resp in `apps_initialize` and you'll get different values if the profile is set at those levels.

## `fnd_message` — translated messages

```sql
DECLARE
  v_msg VARCHAR2(4000);
BEGIN
  fnd_message.set_name('FND','FND_GENERIC_MESSAGE');     -- FND_GENERIC_MESSAGE is a built-in passthrough
  fnd_message.set_token('MESSAGE','hello from apps');
  v_msg := fnd_message.get;
  dbms_output.put_line(v_msg);
END;
/
```

**Verified output:** `hello from apps`

For real use, define your message in *Application Developer → Application → Messages* with your own tokens (e.g. `XXC_EMP_NOT_FOUND` with token `EMP_NUM`), then `set_token('EMP_NUM', '12345')` before `get`.

## `fnd_file` — log from a concurrent program

`fnd_file` only works when running **inside a concurrent request** — it writes to the request's LOG and OUTPUT files. From SQL*Plus it silently no-ops (no file handle). Usage:

```sql
BEGIN
  fnd_file.put_line(fnd_file.log,    'Starting load at '||TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'));
  fnd_file.put_line(fnd_file.output, 'Customer,Amount');      -- CSV header on OUTPUT
  -- ... inside a loop ...
  fnd_file.put_line(fnd_file.output, cust||','||amt);
END;
```

To see results, retrieve the request's log/output file after submission from *View Concurrent Requests → View Log / View Output*.

## `fnd_request.submit_request` — submit another concurrent program

```sql
SET SERVEROUTPUT ON
DECLARE
  v_req_id NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20420, 1);
  v_req_id := fnd_request.submit_request(
    application => 'FND',          -- application short name
    program     => 'FNDSCURS',     -- concurrent program short name (Active Users)
    description => NULL,
    start_time  => NULL,
    sub_request => FALSE);
  IF v_req_id = 0 THEN
    dbms_output.put_line('FAILED: '||fnd_message.get);
  ELSE
    dbms_output.put_line('submitted request_id=' || v_req_id);
    COMMIT;                        -- MUST commit to release the request to the CM
  END IF;
END;
/
```

**Verified on Vision:** call returned a positive `request_id` (e.g. `7623590`). Without the `COMMIT`, the CM never sees the row — `fnd_request.submit_request` just inserts into `FND_CONCURRENT_REQUESTS`.

### Passing parameters

Use `fnd_request.submit_request('APP', 'PROG', ..., sub_request, argument1, argument2, ...)`. Parameters are positional — pad with `CHR(0)` or omit trailing ones. For a real program with parameters:

```sql
v_req_id := fnd_request.submit_request(
    'PO','POXRPORC',NULL,NULL,FALSE,
    TO_CHAR(SYSDATE-30,'YYYY/MM/DD HH24:MI:SS'),      -- argument1: date from
    TO_CHAR(SYSDATE,   'YYYY/MM/DD HH24:MI:SS'));     -- argument2: date to
```

## Pattern every custom program follows

```sql
CREATE OR REPLACE PACKAGE BODY xxc_sample_pkg AS
  PROCEDURE main(errbuf  OUT VARCHAR2,
                 retcode OUT VARCHAR2,
                 p_from  IN  DATE,
                 p_to    IN  DATE) IS
  BEGIN
    -- 1. (CM already set context, but explicit re-init is defensive)
    fnd_global.apps_initialize(fnd_global.user_id,
                               fnd_global.resp_id,
                               fnd_global.resp_appl_id);
    fnd_file.put_line(fnd_file.log, 'From='||p_from||' To='||p_to);

    -- 2. ... business logic ...

    retcode := '0';                                     -- 0=success,1=warning,2=error
    errbuf  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SUBSTR(SQLERRM,1,240);
      fnd_file.put_line(fnd_file.log, 'ERROR: '||errbuf);
  END main;
END xxc_sample_pkg;
/
```

Register this `main` procedure as a concurrent program (Executable type `PL/SQL Stored Procedure`, execution method `PL/SQL Stored Procedure`). The CM passes `errbuf` / `retcode` automatically, and your `p_from` / `p_to` appear as user parameters.

## Next

Back to [./](./).
