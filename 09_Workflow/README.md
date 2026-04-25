# 09 — Oracle Workflow

## What it is
**Oracle Workflow** drives approval chains, notifications, and any business‑process flow across EBS modules (PO approval, iExpenses, HR self‑service, AP holds). You design flows in **Workflow Builder** (Windows client), save them to `.wft` files, and load them into the database with `WFLOAD`.

Runtime stores process state in `WF_ITEMS`, `WF_ITEM_ACTIVITY_STATUSES`, `WF_NOTIFICATIONS`. The **Workflow Background Engine** concurrent program advances deferred/timed‑out activities.

## How to use
1. Install **Oracle Workflow Builder** on a Windows client (comes with EBS client tools).
2. Connect to the database and **open an item type** (e.g. `POAPPRV`) — or create a new one, e.g. `XXCEXP`.
3. Design: **Attributes**, **Processes**, **Functions** (PL/SQL), **Notifications**, **Lookups**, **Messages**.
4. Save locally as `.wft`, then upload with `WFLOAD`.
5. From PL/SQL, create and start a process instance with `WF_ENGINE`.

## Sample

Upload definition:

```bash
# On the Apps tier as oracle
WFLOAD apps/<apps_pwd> 0 Y UPLOAD XXCEXP.wft
```

Kick off an instance:

```plsql
DECLARE
    l_itemtype VARCHAR2(8)   := 'XXCEXP';
    l_itemkey  VARCHAR2(240) := 'EXP-' || TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS');
BEGIN
    -- 1) Create the process
    wf_engine.createprocess(
        itemtype => l_itemtype,
        itemkey  => l_itemkey,
        process  => 'EXPENSE_APPROVAL'
    );

    -- 2) Set attributes
    wf_engine.setitemattrtext(l_itemtype, l_itemkey, 'EMPLOYEE_NAME', 'John Doe');
    wf_engine.setitemattrnumber(l_itemtype, l_itemkey, 'EXPENSE_AMOUNT', 1250);
    wf_engine.setitemownernumber(l_itemtype, l_itemkey, fnd_global.user_id);

    -- 3) Start it
    wf_engine.startprocess(l_itemtype, l_itemkey);

    COMMIT;
    DBMS_OUTPUT.put_line('Started ' || l_itemtype || '/' || l_itemkey);
END;
/
```

PL/SQL function activity signature (what Workflow Builder expects):

```plsql
PROCEDURE validate_amount (
    itemtype  IN  VARCHAR2,
    itemkey   IN  VARCHAR2,
    actid     IN  NUMBER,
    funcmode  IN  VARCHAR2,
    resultout OUT VARCHAR2
);
```

Monitor a running flow: *Workflow Administrator Web Applications → Status Monitor* or query `wf_items`.

## Next commands
- Build a simple 2‑level approval flow from scratch with Builder screenshots.
- Notifications: FYI vs Response, `#HIDE_REASSIGN` and other special tokens.
- Tuning: `WF_PURGE`, background engine, stuck activities.
