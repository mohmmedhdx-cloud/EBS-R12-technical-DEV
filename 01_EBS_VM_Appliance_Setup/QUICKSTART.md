# Quickstart — Automated EBS R12.2 Vision VM Setup

Single-page end-to-end guide. Goes from **"OVA is imported and booted"** → **"EBS login page works in my browser"** using the automation in this folder. Follow the steps in order; each one has a **test** to verify it worked before moving on.

Total time: ~25–35 minutes once the VM is booted.

---

## 0. What you need before starting

☐ A freshly-imported **EBS 12.2.12 Vision VM** in VirtualBox — see [00_VM_Config_and_First_Boot/](00_VM_Config_and_First_Boot/) if not yet.
☐ VM is powered on, first-boot wizard done: `root / password`, `oracle / password`, instance name = **`VISION`**.
☐ You can SSH into the VM as both `root` and `oracle` (test with MobaXterm or `ssh root@<vm_ip>`).
☐ Your **Windows host IP** (e.g. `192.168.1.100`) — you'll need it in step 3.

Find the VM's IP from its console:
```bash
hostname -I
```

---

## 1. Copy the scripts to the VM

### Option A — Drag-and-drop in MobaXterm *(easiest)*

1. Open your SSH session to the VM as **oracle** in MobaXterm.
2. The **left panel** is an SFTP browser that auto-navigates to the logged-in user's home (`/home/oracle`).
3. In the MobaXterm side panel, click the "Create new folder" icon and make `ebs_setup`, then enter it.
4. From **Windows Explorer**, open `c:\Users\mk\Desktop\EBS_Technical_Devleopemn\01_EBS_VM_Appliance_Setup\`.
5. **Select all** (`Ctrl+A`) → **drag the files and folders** into the MobaXterm side panel. MobaXterm uploads them via SFTP.
6. If MobaXterm pops up *"Follow terminal folder"* — click **Yes** (keeps the panel and your terminal in sync).

### Option B — `scp` from the command line

From PowerShell or git-bash:
```bash
scp -r "c:/Users/mk/Desktop/EBS_Technical_Devleopemn/01_EBS_VM_Appliance_Setup" \
       oracle@<vm_ip>:/home/oracle/ebs_setup
```

### Test (either option)
In the oracle SSH session:
```bash
ls /home/oracle/ebs_setup/automation
```
Expect to see: `00_run_all.sh  ebs_setup.env.example  lib  preflight.sh  README.md  setup_sudoers.sh`.

> **Windows line endings gotcha:** if you drag from Windows, the shell scripts may arrive with `\r\n` line endings and fail with `bad interpreter: No such file or directory`. One-time fix on the VM:
> ```bash
> sudo yum install -y dos2unix
> find ~/ebs_setup -name '*.sh' -exec dos2unix {} \;
> ```

---

## 2. Make everything executable + install `expect`

SSH in as `oracle`:
```bash
ssh oracle@<vm_ip>
cd ~/ebs_setup
chmod +x */run.sh automation/*.sh
```

Install `expect` (one-time):
```bash
sudo yum install -y expect
```

### Test
```bash
expect -v                                   # prints: expect version 5.45.x
ls -l 02_Enable_SYSADMIN/run.sh             # -rwxr-xr-x  (has 'x')
```

---

## 3. Install the sudoers drop-in (optional but recommended)

Lets the `oracle` user run the 3 root-level phases (01, 08, 10) via `sudo` with no password, so the master driver runs end-to-end without interruption.

```bash
sudo bash ~/ebs_setup/automation/setup_sudoers.sh
```

### Test
```bash
sudo -n service ebscdb status
```
Should return a status line (not a password prompt). If you see `sudo: a password is required`, the drop-in didn't take effect — re-run the setup script.

> **Skipping this step?** Fine. Run phases 01 / 08 / 10 in a separate `root@<vm_ip>` SSH session; everything else as oracle.

---

## 4. Configure `ebs_setup.env`

```bash
cd ~/ebs_setup/automation
cp ebs_setup.env.example ebs_setup.env
chmod 600 ebs_setup.env
vi ebs_setup.env
```

**The only required edit:** change `HOST_IP='192.168.1.100'` to your **actual Windows host IP**.

All other defaults (`NEW_PASSWORD='password'`, `APPS_PASSWORD='apps'`, `NEW_WLS_PASSWORD='Welcome01'`, etc.) match the project convention — no need to change unless you want different passwords.

### Test
```bash
grep ^HOST_IP ebs_setup.env                 # shows your real IP
```

---

## 5. Run the preflight check

```bash
./preflight.sh
```

**Expected last line:** `Preflight PASSED — ready to run ./00_run_all.sh`.

If it reports `FAILED`, fix each flagged item (missing package, missing file, sudo not configured, etc.) before moving on.

---

## 6. Run the master driver

```bash
./00_run_all.sh
```

Answer `y` at the single confirmation prompt. The driver will:

1. Show the banner with your config values
2. Run all 10 phases in order, streaming each phase's output
3. Land you back at the prompt after ~20–25 minutes with a summary

Log files: `~/log/ebs_setup_<timestamp>/NN_*.log` — one per phase.

---

## 7. Per-phase smoke tests (verify as you go)

If you want to watch a specific phase, open a **second SSH session** as `oracle` and run these while the driver is running or after it finishes:

### After phase 01 (DB started)
```bash
ps -ef | grep -i pmon | grep -v grep       # ora_pmon_EBSCDB process
lsnrctl status EBSCDB | grep 'service EBSDB'
```

### After phases 02–04 (user passwords set)
```bash
ls ~/log/L*.log | wc -l                     # > 40 log files
grep -H 'changed successfully' ~/log/L*.log | wc -l   # > 40 success lines
egrep -i 'error|failed|invalid' ~/log/L*.log          # should output NOTHING
```

### After phase 06 (SQL*Net invited_nodes)
From your **Windows** host:
```powershell
Test-NetConnection apps.example.com -Port 1521
```
`TcpTestSucceeded: True` = listener is reachable from your PC.

### After phase 07 (DB user passwords changed)
```bash
sqlplus system/password@EBSDB <<< 'SELECT name FROM v$database;'
```
Should return `EBSCDB`.

### After phase 08 (apps tier running)
```bash
. /u01/install/APPS/EBSapps.env run
adopmnctl.sh status                           # table of running services, all "Alive"
```
Or from Windows:
```powershell
Test-NetConnection apps.example.com -Port 8000   # HTTP server
```

### After phase 09 (WebLogic pw changed)
Open `http://apps.example.com:7001/console` in a browser → log in as **weblogic / Welcome01**.

### After phase 10 (firewall off)
From Windows:
```powershell
Test-NetConnection apps.example.com -Port 7001
```
All three ports (1521, 7001, 8000) should now return `True`.

---

## 8. Final acceptance test — log in to EBS

Open in your Windows browser:

```
http://apps.example.com:8000/OA_HTML/AppsLogin
```

Log in as either:
- **SYSADMIN** / `password` — admin view
- **OPERATIONS** / `password` — a typical Vision demo user with operational responsibilities

You should see the EBS home page with responsibilities listed. ✅

---

## If a phase fails mid-run

Each phase script is idempotent-ish — you can re-run just the failing one:

```bash
cd ~/ebs_setup/09_Update_WebLogic     # whichever phase failed
./run.sh
```

Common failure modes:

| Phase | Symptom | Fix |
|---|---|---|
| 01 | `ORA-01102: cannot mount database in EXCLUSIVE mode` | `rm $ORACLE_HOME/dbs/lk* /tmp/.oracle*` as oracle, retry |
| 04 | `Enter password for EBS_SYSTEM:` returns auth error | `CURRENT_EBS_SYSTEM_PASSWORD` in env is wrong — check if someone already ran phase 04 |
| 06 | `lsnrctl stop` fails | Listener name mismatch — check `CDB_NAME` in env |
| 09 | `ERROR: Invalid WLS Admin user credentials` | `CURRENT_WLS_PASSWORD` in env is wrong (default `welcome1`; if previously changed, set the real one) |
| 09 | Mid-tier didn't actually stop | Run `adstpall.sh -skipNM -skipAdmin` manually once, then re-run `09/run.sh` |

After fixing, you can resume from a specific phase:
```bash
# Quick and dirty — just run the remaining phases one by one
cd ~/ebs_setup/05_Verify_Logs    && ./run.sh
cd ~/ebs_setup/06_Configure_Sqlnet && ./run.sh
cd ~/ebs_setup/07_Alter_DB_Users   && ./run.sh
# ... etc
```

---

## 9. Post-setup: snapshot the VM

Before you start using it for development, take a **VirtualBox snapshot** so you can rewind if something gets hosed later:

1. Shut down cleanly (as oracle on the VM):
   ```bash
   . /u01/install/APPS/EBSapps.env run
   adstpall.sh                                 # stops apps tier
   sudo service ebscdb stop                    # stops DB
   sudo shutdown -h now
   ```
2. In VirtualBox GUI → select VM → **Snapshots** → **Take** → name it `"Clean after setup — <date>"`.
3. Start the VM back up for your development work.

---

## TL;DR (for the next time you do this)

```bash
# Windows: drag-and-drop the folder into MobaXterm's SFTP panel → ~/ebs_setup
#          (or: scp -r 01_EBS_VM_Appliance_Setup oracle@<vm_ip>:/home/oracle/ebs_setup)

# VM, as oracle:
cd ~/ebs_setup
sudo yum install -y expect dos2unix
find . -name '*.sh' -exec dos2unix {} \;          # fix CRLF if dragged from Windows
chmod +x */run.sh automation/*.sh
sudo bash automation/setup_sudoers.sh
cd automation
cp ebs_setup.env.example ebs_setup.env
sed -i "s/^HOST_IP=.*/HOST_IP='$(echo $SSH_CLIENT | awk '{print $1}')'/" ebs_setup.env
./preflight.sh && ./00_run_all.sh
```

The `sed` line auto-fills `HOST_IP` with whatever IP your SSH session came from (i.e. your Windows box).
