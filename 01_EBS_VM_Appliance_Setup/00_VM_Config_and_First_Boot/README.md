# 00 — VM Import + First Boot + SSH Connection

Everything needed to go from "downloaded `.ova` on disk" to "I can SSH into the VM as root from MobaXterm".

Prerequisite for [MANUAL_SETUP.md](MANUAL_SETUP.md) and the [scripts/](scripts/).

---

## Prerequisites

- Windows 10/11 host
- **Oracle VirtualBox** installed (≥ 6.1)
- EBS R12.2.12 Vision `.ova` file downloaded from [Oracle Software Delivery Cloud](https://edelivery.oracle.com) (search *"E-Business Suite 12.2 Vision Oracle VM VirtualBox Appliance"*)
- SSH client — **MobaXterm** recommended (or PuTTY)

---

## 1. Import the OVA into VirtualBox

VirtualBox → **File → Import Appliance** → browse to the `.ova` → **Next** → **Import**.

Keep the defaults but confirm:

| Setting | Value |
|---|---|
| RAM | **≥ 16 GB** |
| vCPU | **≥ 4** |
| Disk | Leave as-is (growable VDI) |
| MAC Address Policy | Generate new MAC addresses for all network adapters |

The import takes 5–15 minutes depending on disk speed.

---

## 2. Switch Adapter 1 to **Bridged**

Select the imported VM → **Settings** → **Network** → **Adapter 1**:

- ☑ **Enable Network Adapter**
- **Attached to:** `Bridged Adapter`
- **Name:** pick your actually-in-use NIC (the Wi-Fi one if you're on Wi-Fi, the Ethernet one if you're wired)
- **Advanced → Promiscuous Mode:** `Allow All` *(safe default, avoids issues on some routers)*
- **Cable Connected:** ☑

Click **OK**. Leave Adapter 2/3/4 disabled — Bridged alone is enough.

> Why Bridged? It puts the VM on the same LAN as your Windows host — same subnet, same DHCP — so MobaXterm can reach it at its own IP without any VirtualBox-internal routing gymnastics.

---

## 3. Start the VM and answer the first-boot prompts

Click **Start**. The VM boots and drops into a **first-time configuration script** that runs in the console. Answer:

| Prompt | Enter |
|---|---|
| Set new **root** password | `password` |
| Re-enter **root** password | `password` |
| Set new **oracle** password | `password` |
| Re-enter **oracle** password | `password` |
| Enter the **Instance Name** | **`VISION`** *(all capitals)* |

The script finalizes config (sets hostname, generates SSH keys, configures services) and lands you at the Linux login prompt on the console.

> If you missed a prompt or want to re-run the script, you can as root:  
> `/u01/install/APPS/scripts/firstbootconfig.sh` *(exact name varies by OVA release — check `/u01/install/APPS/scripts/`)*.

---

## 4. Find the VM's IP address

Log in on the VirtualBox console as `root` / `password` and run:

```bash
ip a | grep -A1 'eth0\|enp0s' | grep inet
# or
hostname -I
```

Example output:
```
192.168.1.101
```

Note this IP — that's what you'll point MobaXterm at.

---

## 5. Connect via MobaXterm (or any SSH client)

Open **MobaXterm** → **Session** → **SSH**:

| Field | Value |
|---|---|
| Remote host | the VM's IP (e.g. `192.168.1.101`) |
| Specify username | ☑ `root` |
| Port | `22` |

Click **OK** → password: `password`. You should land in `/root`.

Open a **second** session the same way with username `oracle` — that's the session you'll run most of the EBS commands in.

From here on **every command in the setup flow is executed inside MobaXterm** — not in the VirtualBox console.

---

## 6. (Recommended) Add a friendly hostname on the Windows host

So you can open EBS at `http://apps.example.com:8000` later instead of by IP.

Open **Notepad as Administrator** → open `C:\Windows\System32\drivers\etc\hosts` → append:

```
192.168.1.101    apps.example.com
```

Replace the IP with whatever you got from step 4. Save.

Inside the VM, check `/etc/hosts` already has the equivalent line (the first-boot script usually adds it):

```bash
grep apps.example.com /etc/hosts
```

If missing, add it as root:
```bash
echo "$(hostname -I | awk '{print $1}')    apps.example.com" >> /etc/hosts
```

---

## 7. Confirm everything works

From **Windows PowerShell**:

```powershell
ping apps.example.com
Test-NetConnection apps.example.com -Port 22
```

Both should succeed. SSH should already work from MobaXterm at this point.

---

## You're ready

✅ VM imported and running on a Bridged adapter  
✅ `root` / `password` and `oracle` / `password` both set  
✅ You can SSH into the VM from MobaXterm  
✅ Windows hosts file maps `apps.example.com` to the VM

**Next:**
- 📘 Manual — [MANUAL_SETUP.md](MANUAL_SETUP.md) — 10 phases to turn this into a usable EBS instance
- 🤖 Or automated — [scripts/](scripts/) — the same 10 phases run hands-off
