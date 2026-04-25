# Phase 99 — Enable Integrated SOA Gateway *(optional)*

**Run as:** `oracle` &nbsp;&nbsp; **Time:** 2-5 minutes

## What it does
Enables **Oracle E-Business Suite Integrated SOA Gateway (ISG)** — the component that lets you expose seeded or custom APIs as SOAP or REST services via the **Integration Repository** responsibility.

Skip this phase unless you specifically plan to:
- Publish a custom PL/SQL package as a REST/SOAP service
- Consume EBS seeded APIs from an external system
- Do OER / irep-driven integration work

## Manual

```bash
cd ~/log
/u01/install/APPS/scripts/enableISG.sh
```

The script is non-interactive. Writes `L*.log` + `O*.out` in `~/log`.

## Automated

```bash
./run.sh
```

## Verify

Log in to EBS as SYSADMIN → Responsibility: **Integrated SOA Gateway** → **Integration Repository**. If you can browse the repository, ISG is enabled.

From the DB:
```sql
SELECT parameter_id, parameter_value
FROM   fnd_oam_context_files_vl
WHERE  parameter_id LIKE 's\_isg\_%' ESCAPE '\';
```
Should return the ISG parameters with non-null values.

## Next

No next phase. Return to the main index: [../](../)
