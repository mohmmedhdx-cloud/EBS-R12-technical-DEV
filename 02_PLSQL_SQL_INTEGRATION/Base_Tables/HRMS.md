# HRMS — Base Tables & Joins (SQL & PL/SQL for EBS)

All tables below **verified against a live Vision R12.2.12 instance** (`apps/apps@EBSDB`). None of the HR tables use `ORG_ID` — HR is partitioned by **`BUSINESS_GROUP_ID`** instead. MOAC (`mo_global.set_policy_context`) does **not** apply to HR; to scope by business group, filter `BUSINESS_GROUP_ID` explicitly.

## Tables

| Table | Kind | BG column | Date-tracked | Purpose |
|---|---|---|---|---|
| `PER_ALL_PEOPLE_F` | table | BUSINESS_GROUP_ID | ✅ effective_start_date / effective_end_date | One row per person per date-range |
| `PER_ALL_ASSIGNMENTS_F` | table | BUSINESS_GROUP_ID | ✅ | One row per assignment per date-range |
| `PER_PERIODS_OF_SERVICE` | table | BUSINESS_GROUP_ID | no | Employment periods (hire → termination) |
| `PER_PERSON_TYPES` | table | BUSINESS_GROUP_ID | no | Person type codes (EMP, CWK, EX_EMP, APL, …) |
| `PER_PERSON_TYPES_TL` | table | — | no | Translated meanings for person types |
| `PER_PERSON_TYPE_USAGES_F` | table | — | ✅ | Date-tracked type assignments on a person |
| `PER_JOBS` | table | BUSINESS_GROUP_ID | no | Jobs |
| `PER_JOBS_TL` | table | — | no | Translated job names |
| `PER_GRADES` | table | BUSINESS_GROUP_ID | no | Grades |
| `PER_ALL_POSITIONS` | table | BUSINESS_GROUP_ID | no | Positions (pre-R12 structure) |
| `HR_ALL_POSITIONS_F` | table | BUSINESS_GROUP_ID | ✅ | Positions (R12 date-tracked) |
| `HR_ALL_ORGANIZATION_UNITS` | table | BUSINESS_GROUP_ID | no | Organization units (HR orgs, OUs, inventory orgs, …) |
| `HR_ALL_ORGANIZATION_UNITS_TL` | table | — | no | Translated org names |
| `HR_ORGANIZATION_INFORMATION` | table | — | no | Org attributes (classifications like "HR Org", "Operating Unit") |
| `HR_OPERATING_UNITS` | **view** | BUSINESS_GROUP_ID | no | Filtered view of orgs classified as Operating Units |
| `HR_LOCATIONS_ALL` | table | BUSINESS_GROUP_ID | no | Physical locations |
| `HR_LOCATIONS_ALL_TL` | table | — | no | Translated location names |
| `PER_BUSINESS_GROUPS` | **view** | BUSINESS_GROUP_ID | no | Shortcut to HR orgs classified as BG |
| `PER_ADDRESSES` | table | BUSINESS_GROUP_ID | no | Person addresses (date-ranged via start/end) |
| `PER_PHONES` | table | — | no | Person phones |
| `PER_CONTACT_RELATIONSHIPS` | table | BUSINESS_GROUP_ID | no | Dependents, beneficiaries, emergency contacts |
| `PER_ABSENCE_ATTENDANCES` | table | BUSINESS_GROUP_ID | no | Leaves / absences |
| `PER_ABSENCE_ATTENDANCE_TYPES` | table | BUSINESS_GROUP_ID | no | Absence types |
| `PAY_ALL_PAYROLLS_F` | table | BUSINESS_GROUP_ID | ✅ | Payrolls |
| `PAY_PAYROLL_ACTIONS` | table | BUSINESS_GROUP_ID | no | Payroll runs |
| `PAY_ASSIGNMENT_ACTIONS` | table | — | no | One row per assignment per payroll run |
| `PAY_ELEMENT_TYPES_F` | table | BUSINESS_GROUP_ID | ✅ | Element definitions (earnings, deductions, …) |
| `PAY_ELEMENT_CLASSIFICATIONS` | table | BUSINESS_GROUP_ID | no | Element categories |
| `PAY_ELEMENT_ENTRIES_F` | table | — | ✅ | Element entries on assignments |
| `PER_ORGANIZATION_STRUCTURES` | table | BUSINESS_GROUP_ID | no | Organization hierarchy definitions |
| `PER_ORG_STRUCTURE_VERSIONS` | table | BUSINESS_GROUP_ID | no | Versions of those hierarchies |
| `PER_ORG_STRUCTURE_ELEMENTS` | table | BUSINESS_GROUP_ID | no | Parent-child pairs inside a hierarchy |
| `PER_POSITION_STRUCTURES` | table | BUSINESS_GROUP_ID | no | Position hierarchies |
| `PER_PEOPLE_F` | **view** | BUSINESS_GROUP_ID | ✅ | Security-filtered view on PER_ALL_PEOPLE_F |
| `PER_ASSIGNMENTS_F` | **view** | BUSINESS_GROUP_ID | ✅ | Security-filtered view on PER_ALL_ASSIGNMENTS_F |
| `PER_PEOPLE_X` | **view** | BUSINESS_GROUP_ID | — | Current-date-filtered convenience view |
| `PER_ASSIGNMENTS_X` | **view** | BUSINESS_GROUP_ID | — | Current-date-filtered convenience view |

## Organization Unit (OU) note

HR tables don't carry `ORG_ID`. If you need to report by **operating unit**, join through `HR_ALL_ORGANIZATION_UNITS` / `HR_ORGANIZATION_INFORMATION` to find orgs classified as *Operating Unit*, or use the `HR_OPERATING_UNITS` view (which already filters for classification `OPERATING_UNIT`).

No `mo_global.set_policy_context` is required for HR selects; it does not filter HR tables.

## Canonical joins (all verified to return rows on Vision)

### Person → Assignment → Job → Position → Organization → Location

```sql
SELECT papf.employee_number,
       papf.full_name,
       pj.name         AS job_name,
       hpf.name        AS position_name,
       haou.name       AS organization_name,
       hla.location_code
FROM   per_all_people_f       papf
JOIN   per_all_assignments_f  paaf ON paaf.person_id      = papf.person_id
JOIN   per_jobs               pj   ON pj.job_id           = paaf.job_id
LEFT  JOIN hr_all_positions_f hpf  ON hpf.position_id     = paaf.position_id
     AND SYSDATE BETWEEN hpf.effective_start_date AND hpf.effective_end_date
JOIN   hr_all_organization_units haou ON haou.organization_id = paaf.organization_id
LEFT  JOIN hr_locations_all   hla  ON hla.location_id     = paaf.location_id
WHERE  SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
AND    SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
AND    paaf.primary_flag = 'Y'
AND    papf.current_employee_flag = 'Y';
```

### Person → Person type (current type)

```sql
SELECT papf.employee_number,
       papf.full_name,
       ppt.user_person_type,
       ppt.system_person_type
FROM   per_all_people_f  papf
JOIN   per_person_types  ppt ON ppt.person_type_id = papf.person_type_id
WHERE  SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
AND    papf.business_group_id = 202;                  -- Vision Operations
```

### Person → Periods of service (hire / termination history)

```sql
SELECT papf.employee_number,
       papf.full_name,
       pps.date_start,
       pps.actual_termination_date,
       pps.leaving_reason
FROM   per_all_people_f       papf
JOIN   per_periods_of_service pps  ON pps.person_id = papf.person_id
WHERE  SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
ORDER  BY pps.date_start DESC;
```

### Assignment → Grade + Payroll

```sql
SELECT paaf.assignment_number,
       pg.name            AS grade,
       pap.payroll_name
FROM   per_all_assignments_f paaf
LEFT  JOIN per_grades         pg   ON pg.grade_id   = paaf.grade_id
LEFT  JOIN pay_all_payrolls_f pap  ON pap.payroll_id = paaf.payroll_id
     AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
WHERE  SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
AND    paaf.primary_flag = 'Y';
```

### Organization → its classifications

```sql
SELECT haou.name,
       hoi.org_information_context,
       hoi.org_information1,
       hoi.org_information2
FROM   hr_all_organization_units   haou
JOIN   hr_organization_information hoi ON hoi.organization_id = haou.organization_id
WHERE  hoi.org_information_context = 'CLASS'
ORDER  BY haou.name;
```

### Organization hierarchy traversal (one level down)

```sql
SELECT ver.version_number                          AS version,
       parent.name                                 AS parent_org,
       child.name                                  AS child_org
FROM   per_organization_structures   str
JOIN   per_org_structure_versions    ver ON ver.organization_structure_id = str.organization_structure_id
JOIN   per_org_structure_elements    el  ON el.org_structure_version_id   = ver.org_structure_version_id
JOIN   hr_all_organization_units     parent ON parent.organization_id = el.organization_id_parent
JOIN   hr_all_organization_units     child  ON child.organization_id  = el.organization_id_child
WHERE  SYSDATE BETWEEN ver.date_from AND NVL(ver.date_to, SYSDATE)
ORDER  BY parent.name, child.name;
```

### Absences

```sql
SELECT papf.employee_number,
       paat.name          AS absence_type,
       paa.date_start,
       paa.date_end,
       paa.absence_days
FROM   per_all_people_f                papf
JOIN   per_absence_attendances         paa  ON paa.person_id = papf.person_id
JOIN   per_absence_attendance_types    paat ON paat.absence_attendance_type_id = paa.absence_attendance_type_id
WHERE  paa.date_start BETWEEN TRUNC(SYSDATE,'YYYY') AND SYSDATE;
```

## Date-tracked pattern — always use this

Any table ending in `_F` is date-tracked. Filtering by `SYSDATE BETWEEN effective_start_date AND effective_end_date` gives you the **current** row for each entity. Without it you get multiple rows per person/assignment/payroll over time.

```sql
-- Correct:
SELECT person_id, full_name
FROM   per_all_people_f
WHERE  SYSDATE BETWEEN effective_start_date AND effective_end_date;

-- Wrong — returns history rows too:
SELECT person_id, full_name
FROM   per_all_people_f;
```

## Next

Back to [../../Base_Tables/](../Base_Tables/) · Also see [../Oracle_APIs/HR/](../Oracle_APIs/HR/) for the matching Create/Update/Terminate API scripts.
