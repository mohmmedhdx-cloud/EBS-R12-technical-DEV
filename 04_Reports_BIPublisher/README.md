# 04 — Reports: XML / BI Publisher

## What it is
In EBS R12 the modern reporting stack is **BI Publisher (XML Publisher)**. You separate:
- **Data source** — a concurrent program that outputs XML (PL/SQL package, Oracle Report in XML mode, or a Data Template).
- **Template** — an `.rtf` (Word) or `.xsl` file that formats that XML.
- **Delivery** — PDF, Excel, HTML, or CSV, chosen at submission time.

Old‑style `.rdf` (Oracle Reports Builder) reports still exist in R12 but all new custom reports should be BI Publisher.

## How to use
1. Build a concurrent program whose output is **XML** — either:
   - a PL/SQL package that writes XML via `FND_FILE.OUTPUT`, or
   - a **Data Template** (`.xml` datafile) registered as a Data Definition.
2. Design the **RTF template** in Microsoft Word with the BI Publisher Desktop add‑in (Insert → Fields, Table Wizard, etc.).
3. In the **XML Publisher Administrator** responsibility:
   - *Data Definitions* → create a new Data Def with a **Code** matching your concurrent program short name.
   - *Templates* → upload the RTF, link it to the Data Definition, set default output = PDF.
4. Run the concurrent program — at submission you pick the template and output format.

## Sample

Minimal data template (`XXC_EMP_RPT.xml`):

```xml
<dataTemplate name="XXC_EMP_RPT" description="Active employees" version="1.0">
  <parameters>
    <parameter name="p_department_id" dataType="number" defaultValue="0"/>
  </parameters>
  <dataQuery>
    <sqlStatement name="Q_EMPS">
      <![CDATA[
        SELECT papf.employee_number EMP_NO,
               papf.full_name       EMP_NAME,
               paaf.organization_id DEPT_ID
        FROM   per_all_people_f      papf
        JOIN   per_all_assignments_f paaf ON paaf.person_id = papf.person_id
        WHERE  paaf.organization_id = :p_department_id
        AND    SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
      ]]>
    </sqlStatement>
  </dataQuery>
  <dataStructure>
    <group name="G_EMP" source="Q_EMPS">
      <element name="EMP_NO"   value="EMP_NO"/>
      <element name="EMP_NAME" value="EMP_NAME"/>
      <element name="DEPT_ID"  value="DEPT_ID"/>
    </group>
  </dataStructure>
</dataTemplate>
```

RTF template body (simplified):

```
Employees in Department <?DEPT_ID?>

| Number           | Name             |
| <?for-each:G_EMP?><?EMP_NO?> | <?EMP_NAME?><?end for-each?> |
```

## Next commands
- Step‑by‑step BIP Desktop install and first RTF build.
- Converting a legacy `.rdf` to BI Publisher.
- Using XDOLoader to migrate templates (see folder 19).
