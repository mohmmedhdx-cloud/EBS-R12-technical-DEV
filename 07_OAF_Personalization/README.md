# 07 — OAF Personalization

## What it is
**Personalization** changes an OAF page's behavior or look **without recompiling Java** — by storing metadata overrides in `JDR_*` tables. Changes survive patching (unlike custom code) because they're applied on top of the seeded page at runtime.

You can personalize at multiple levels: **Function, Site, Org, Responsibility, User** — lower levels override higher ones.

## How to use
1. Set profile options for your user:
   - `FND: Personalization Region Link Enabled = Yes`
   - `Personalize Self-Service Defn = Yes`
   - `FND: Diagnostics = Yes` (optional, for About This Page).
2. Log in and navigate to the page you want to personalize.
3. Click the **Personalize Page** link at the top-right (or *Personalize Region* on a specific region).
4. In the hierarchy grid, pick the level (Responsibility is most common) and click the pencil.
5. Change the item's **Rendered**, **Required**, **Read Only**, **Prompt**, **Initial Value**, or re‑order regions.
6. *Apply → Return to Application* — refresh and your change is live.

To migrate personalizations between instances, use **FNDLOAD** with `jdrload` / `jdrupdate` (see folder 18).

## Sample — scenarios

**a) Hide the "Middle Name" field on the Employee page for a specific responsibility.**

- Personalize Page → pick *Responsibility: XXC HR Manager* row → pencil.
- Locate the `MiddleName` item → set `Rendered = False` → Apply.

**b) Make "National Identifier" required.**

- Same screen → `NationalIdentifier` item → `Required = True`.

**c) Change the prompt.**

- `EmpNumber` item → `Prompt = Badge No.`.

**d) Export the personalization for migration:**

```bash
# On the Apps tier as oracle
FNDLOAD apps/<pwd> 0 Y DOWNLOAD $FND_TOP/patch/115/import/xlfmcustom.lct \
    xxc_emp_search_pers.ldt JDR_CUSTOMIZATIONS \
    CUSTOMIZATION_PATH='/oracle/apps/per/selfservice/newhire/webui/customizations/site/0/ReviewPG'
```

## Next commands
- Difference between *Personalization* (metadata) and *Extension* (subclassed CO/AM).
- Migrate personalizations with FNDLOAD (`jdrload`) step-by-step.
- Troubleshooting: why a personalization doesn't apply (level priority, clear cache, Apache bounce).
