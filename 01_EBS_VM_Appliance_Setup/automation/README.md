# Automation — shared driver + helpers

This folder holds the pieces every phase script needs:

| File | Purpose |
|---|---|
| `00_run_all.sh` | Master driver — calls every `../NN_*/run.sh` in order |
| `setup_sudoers.sh` | One-time: grants `oracle` passwordless sudo for the 3 root phases |
| `ebs_setup.env.example` | Template for the config file |
| `ebs_setup.env` | Your real config (gitignored — plaintext passwords) |
| `lib/common.sh` | Shared bash helpers sourced by every phase script |
| `.gitignore` | Excludes `ebs_setup.env` and logs |

## One-time setup

On the VM, after step 0 (VM imported + booted + reachable via SSH):

```bash
# 1. Install the expect utility
sudo yum install -y expect

# 2. (Recommended) Grant oracle passwordless sudo for root-level phases
sudo bash setup_sudoers.sh

# 3. Create the env file and fill in HOST_IP
cp ebs_setup.env.example ebs_setup.env
chmod 600 ebs_setup.env
vi ebs_setup.env                # set HOST_IP to your Windows-host IP
```

## Run all phases

As the `oracle` user:

```bash
./00_run_all.sh
```

The driver reads the env file, confirms once, then runs every phase's `run.sh` in order. Logs go to `~/log/ebs_setup_<timestamp>/`.

## Run one phase at a time

Each phase folder is self-contained:

```bash
cd ../02_Enable_SYSADMIN
./run.sh
```

The script guards on who's logged in (`root` vs `oracle`) and fails fast if wrong.

## Run without sudo

If you skipped `setup_sudoers.sh`, run the root phases in a separate `root@` SSH session:

```bash
# Root session
cd /home/oracle/ebs_setup/01_Start_DB   && ./run.sh    # phase 01
# ... wait ...
cd /home/oracle/ebs_setup/08_Start_Apps && ./run.sh    # phase 08
cd /home/oracle/ebs_setup/10_Disable_Firewall && ./run.sh  # phase 10

# Oracle session
# run phases 02-07, then 09, in sequence
```

## Config cheat sheet (`ebs_setup.env`)

| Var | Default | Meaning |
|---|---|---|
| `NEW_PASSWORD` | `password` | applied to SYSADMIN, demo users, product schemas, SYS, SYSTEM, EBS_SYSTEM |
| `APPS_PASSWORD` | `apps` | the APPS schema password — **not** rotated by this setup |
| `CURRENT_EBS_SYSTEM_PASSWORD` | `manager` | current EBS_SYSTEM pw used to authenticate in phase 04 |
| `CURRENT_WLS_PASSWORD` | `welcome1` | current WebLogic pw used to authenticate in phase 09 |
| `NEW_WLS_PASSWORD` | `Welcome01` | new WebLogic pw set by phase 09 |
| `HOST_IP` | *(required)* | your Windows host IP, added to listener `invited_nodes` in phase 06 |
| `CDB_NAME` | `EBSCDB` | container DB name (Linux service: lowercased) |
| `PDB_NAME` | `EBSDB` | pluggable DB / apps service |
| `CONTEXT_NAME` | `EBSDB_apps` | context dir under `/u01/install/APPS/fs1/inst/apps/` |

## Safety

- `ebs_setup.env` contains plaintext passwords → `chmod 600`, `.gitignore`d, never commit it.
- Use this only on a local sandbox Vision VM. Nothing here should be reachable from the internet.

## Copy to VM (from Windows host)

```bash
scp -r 01_EBS_VM_Appliance_Setup oracle@<vm_ip>:/home/oracle/ebs_setup
ssh oracle@<vm_ip>
cd ~/ebs_setup
chmod +x */run.sh automation/*.sh
cd automation
cp ebs_setup.env.example ebs_setup.env && vi ebs_setup.env
./00_run_all.sh
```
