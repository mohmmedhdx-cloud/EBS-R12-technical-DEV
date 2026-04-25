# 06 — OAF Development (OA Framework)

## What it is
**OA Framework (OAF)** is Oracle's Java/JSP-based self-service UI framework used across R12 for pages like iProcurement, iRecruitment, iExpenses, and most modern "Manager" screens. You build OAF pages in **Oracle JDeveloper 10g** (the exact patched version shipped for your EBS code‑line).

Key components:
- **PG.xml (Page)** — page definition, items, regions.
- **Controller (CO)** — Java class handling `processRequest` / `processFormRequest`.
- **Application Module (AM)** — transactional root, holds VOs, state.
- **View Object (VO)** — SQL-backed query.
- **Entity Object (EO)** — row‑level DML + validation.

## How to use
1. **Install JDeveloper** — the exact P‑number patch that matches your EBS version (e.g. Patch 17204589 for R12.2.x). Extract to a path without spaces.
2. **Get the DBC file** from the Apps tier: `$FND_SECURE/<SID>.dbc`. Copy to `<jdev>/jdevhome/jdev/dbc_files/secure`.
3. **Create a Workspace + OA Project**, pointing at the DBC and using user `OPERATIONS` / `welcome` (Vision).
4. Build your page: `PG.xml`, CO java class, AM, VO, EO.
5. **Deploy** — FTP compiled classes to `$JAVA_TOP` in the same package path, then bounce Apache or let the class reload.
6. Register the page: create a **Function** of type *SSWA jsp function* with HTML Call = `OA.jsp?page=/xxc/oracle/apps/xxc/emp/webui/EmpSearchPG`, attach to a menu and responsibility.

## Sample — "HelloWorld" controller

```java
package xxc.oracle.apps.xxc.emp.webui;

import oracle.apps.fnd.framework.webui.OAControllerImpl;
import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.apps.fnd.framework.webui.beans.message.OAMessageTextInputBean;

public class XxcEmpSearchCO extends OAControllerImpl {

    public void processRequest(OAPageContext pageContext, OAWebBean webBean) {
        super.processRequest(pageContext, webBean);
        pageContext.writeDiagnostics(this, "XxcEmpSearchCO.processRequest", 1);
    }

    public void processFormRequest(OAPageContext pageContext, OAWebBean webBean) {
        super.processFormRequest(pageContext, webBean);

        if (pageContext.getParameter("SearchBtn") != null) {
            String empNum = (String) pageContext.getParameter("EmpNumber");
            OAMessageTextInputBean nameFld =
                (OAMessageTextInputBean) webBean.findChildRecursive("EmpName");

            // call AM method to execute the VO with this bind
            Serializable[] params = { empNum };
            pageContext.getApplicationModule(webBean)
                       .invokeMethod("searchEmployees", params);
        }
    }
}
```

Register the page behind a function:

```sql
-- via AOL → Application → Function → Define
-- Function         : XXC_EMP_SEARCH
-- User Function    : XXC Employee Search
-- Type             : SSWA jsp function
-- HTML Call        : OA.jsp?page=/xxc/oracle/apps/xxc/emp/webui/EmpSearchPG
```

## Next commands
- Full JDev 10g install and DBC wiring checklist.
- Build a searchable employee page end‑to‑end (EO + VO + AM + CO + PG).
- Debugging: FND profile *FND: Diagnostics = Yes*, *Personalize Self-Service Defn = Yes*, log levels.
