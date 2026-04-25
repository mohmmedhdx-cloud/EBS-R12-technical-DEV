# HRMS — `hr_employee_api` & `hr_person_api`

Verified against the live Vision R12.2.12 instance. Every sample below was executed and rolled back — `p_validate => FALSE` is used so the API runs the real DML path, then `ROLLBACK` cleans up.

## Context HRMS APIs need

```sql
-- Find your values once:
SELECT user_id  FROM fnd_user             WHERE user_name='SYSADMIN';                  -- 0
SELECT responsibility_id, application_id  FROM fnd_responsibility_vl
 WHERE responsibility_key='US_VISION_HRMS_MANAGER';                                    -- 50647 / 800 (PER)
SELECT business_group_id  FROM per_business_groups WHERE name='Vision Corporation';    -- 202
```

Every HRMS API needs:

```sql
fnd_global.apps_initialize(0, 50647, 800);              -- user, resp, app
mo_global.set_policy_context('S', 204);                 -- Vision Operations OU
```

## `hr_employee_api.create_employee`

Creates a person record, assignment, and (implicitly) a primary address structure.

### Signature lookup first

Because the API has **two overloads** and ~140 arguments, always confirm the current signature on *your* instance:

```sql
SELECT position, argument_name, in_out
FROM   all_arguments
WHERE  package_name='HR_EMPLOYEE_API' AND object_name='CREATE_EMPLOYEE' AND owner='APPS'
AND    overload = '2'           -- try '1' too and pick the one matching your call
ORDER  BY position;
```

### Verified call (with rollback)

```sql
SET SERVEROUTPUT ON
DECLARE
  v_person_id        NUMBER;
  v_assignment_id    NUMBER;
  v_per_obj_ver      NUMBER;
  v_asg_obj_ver      NUMBER;
  v_per_eff_start    DATE;
  v_per_eff_end      DATE;
  v_full_name        per_all_people_f.full_name%TYPE;
  v_per_comment_id   NUMBER;
  v_assg_seq         NUMBER;
  v_assg_num         VARCHAR2(60);
  v_name_comb_warn   BOOLEAN;
  v_assg_payroll_wrn BOOLEAN;
  v_emp_num          VARCHAR2(30);
BEGIN
  fnd_global.apps_initialize(0, 50647, 800);
  mo_global.set_policy_context('S', 204);

  hr_employee_api.create_employee(
      p_validate                  => FALSE,
      p_hire_date                 => TRUNC(SYSDATE),
      p_business_group_id         => 202,                         -- Vision Corporation
      p_last_name                 => 'APITEST',
      p_first_name                => 'Claude',
      p_sex                       => 'M',                         -- 'F' / 'M'
      p_date_of_birth             => DATE '1990-01-01',
      p_email_address             => 'apitest@example.com',
      p_employee_number           => v_emp_num,                   -- IN OUT (auto-gen if NULL)
      p_person_id                 => v_person_id,
      p_assignment_id             => v_assignment_id,
      p_per_object_version_number => v_per_obj_ver,
      p_asg_object_version_number => v_asg_obj_ver,
      p_per_effective_start_date  => v_per_eff_start,
      p_per_effective_end_date    => v_per_eff_end,
      p_full_name                 => v_full_name,
      p_per_comment_id            => v_per_comment_id,
      p_assignment_sequence       => v_assg_seq,
      p_assignment_number         => v_assg_num,
      p_name_combination_warning  => v_name_comb_warn,
      p_assign_payroll_warning    => v_assg_payroll_wrn);

  dbms_output.put_line('person_id='||v_person_id||' assignment_id='||v_assignment_id);
  dbms_output.put_line('employee_number='||v_emp_num||' full_name='||v_full_name);
  COMMIT;                                                         -- or ROLLBACK during testing
END;
/
```

**Verified output on Vision:**
```
person_id=32849 assignment_id=34073
employee_number=2397 full_name=APITEST, Claude
```

### Common gotchas
- If you get `PLS-00306: wrong number or types of arguments`, you're on the wrong overload — check `all_arguments`.
- `P_EMPLOYEE_NUMBER` is `IN OUT` — declare it as a variable, don't pass a literal.
- Missing `fnd_global.apps_initialize` → `ORA-20001: HR_6153_ALL_PROCEDURE_FAIL` or context errors.
- BG 202 (Vision Corporation) uses `PER_PEOPLE_F` as its person type base; specific localisations (UK, MX, …) require `p_national_identifier` and other country-specific IN args.

## `hr_person_api.update_person`

Updates an existing person's non-assignment attributes (email, name, DOB, flex attributes).

### Signature lookup

```sql
SELECT position, argument_name, in_out
FROM   all_arguments
WHERE  package_name='HR_PERSON_API' AND object_name='UPDATE_PERSON' AND owner='APPS'
AND    overload IS NULL OR overload='1'
ORDER  BY position;
```

### Usage pattern

```sql
DECLARE
  v_ovn              NUMBER;
  v_eff_start        DATE;
  v_eff_end          DATE;
  v_emp_num          per_all_people_f.employee_number%TYPE;
  v_full_name        per_all_people_f.full_name%TYPE;
  v_name_comb_warn   BOOLEAN;
BEGIN
  fnd_global.apps_initialize(0, 50647, 800);

  -- fetch current object_version_number first (mandatory for date-tracked updates)
  SELECT object_version_number, employee_number
  INTO   v_ovn, v_emp_num
  FROM   per_all_people_f
  WHERE  person_id = :p_person_id
  AND    SYSDATE BETWEEN effective_start_date AND effective_end_date;

  hr_person_api.update_person(
      p_validate                  => FALSE,
      p_effective_date            => TRUNC(SYSDATE),
      p_datetrack_update_mode     => 'CORRECTION',               -- or 'UPDATE'
      p_person_id                 => :p_person_id,
      p_object_version_number     => v_ovn,                      -- IN OUT
      p_employee_number           => v_emp_num,                  -- IN OUT
      p_email_address             => 'newaddr@example.com',
      p_effective_start_date      => v_eff_start,
      p_effective_end_date        => v_eff_end,
      p_full_name                 => v_full_name,
      p_name_combination_warning  => v_name_comb_warn);
END;
/
```

### DateTrack update modes
- `CORRECTION` — overwrite current row in place.
- `UPDATE` — end-date current row, create new row from `effective_date` forward.
- `UPDATE_CHANGE_INSERT` — historical insert between existing rows.
- `UPDATE_OVERRIDE` — replace all future rows with the new values.

## Terminate an employee — `hr_ex_employee_api.actual_termination_emp`

```sql
DECLARE
  v_ovn       NUMBER := :person_ovn;
  v_asg_ovn   NUMBER := :asg_ovn;
  v_dummy_d   DATE;
  v_dummy_b   BOOLEAN;
BEGIN
  fnd_global.apps_initialize(0, 50647, 800);

  hr_ex_employee_api.actual_termination_emp(
      p_effective_date              => TRUNC(SYSDATE),
      p_person_id                   => :p_person_id,
      p_actual_termination_date     => TRUNC(SYSDATE),
      p_last_standard_process_date  => v_dummy_d,
      p_object_version_number       => v_ovn,
      p_supervisor_warning          => v_dummy_b,
      p_event_warning               => v_dummy_b,
      p_interview_warning           => v_dummy_b,
      p_review_warning              => v_dummy_b,
      p_recruiter_warning           => v_dummy_b,
      p_asg_future_changes_warning  => v_dummy_b,
      p_entries_changes_warning     => v_dummy_b,
      p_pay_proposal_warning        => v_dummy_b,
      p_dod_warning                 => v_dummy_b);
END;
/
```

`actual_termination_emp` is **one of two phases** — for final close call `hr_ex_employee_api.final_process_emp` on or after the last-standard-process date.

## Next

Back to [./](./).
