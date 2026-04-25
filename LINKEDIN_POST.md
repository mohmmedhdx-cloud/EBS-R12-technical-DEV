# LinkedIn post — draft

> Draft of a post announcing the EBS VM automation. Tweak the voice, add your GitHub link, and post it from your LinkedIn account. Replace `<YOUR_GITHUB_URL>` before posting.

---

## Option A — Short & punchy (~150 words)

**I just turned 2+ hours of Oracle EBS R12.2 Vision VM setup into one command.**

If you've ever imported the Vision appliance, you know the drill:
- enableSYSADMIN.sh, enableDEMOusers.sh, changeDBpasswords.sh — interactive prompts, one by one
- edit sqlnet_ifile.ora, bounce the listener
- sqlplus alter SYS / SYSTEM / EBS_SYSTEM
- adstpall -skip → txkUpdateEBSDomain.pl → adstrtal with the WebLogic dance
- turn off firewalld
- hope you typed every password consistently

I wrote a set of bash + expect scripts that do all 10 phases end-to-end, driven by a single config file. Runs in ~25 minutes. Every prompt is fed by expect so there are no typos, and every password (including the "default-stays-default" APPS/APPLSYS quirk) is documented.

Perfect for new EBS developers spinning up a learning sandbox.

Repo (MIT-licensed): <YOUR_GITHUB_URL>

If you've set up Vision before — what part did you hate most?

#OracleEBS #EBSR12 #Automation #Bash #Oracle

---

## Option B — Longer, story-first (~250 words)

**Every EBS technical developer I know has a "first Vision VM" horror story.**

Mine looked like this: fresh OVA imported, I spent two evenings clicking through Oracle's post-install doc — setting SYSADMIN's password, unlocking 40+ demo users, rotating schema passwords via FNDCPASS, editing sqlnet_ifile.ora, running the WebLogic dance (adstpall → txkUpdateEBSDomain.pl → adstrtal), and — inevitably — mistyping "Welcome01" somewhere and having to start over.

So I rebuilt it properly.

The result: a set of modular bash + expect scripts. One folder per phase, one README per phase, one `run.sh` per phase. Drop the folder onto a fresh VM, fill in your Windows-host IP, and run:

```
./preflight.sh
./00_run_all.sh
```

~25 minutes later you have a working EBS instance at http://apps.example.com:8000/OA_HTML/AppsLogin.

What's inside:
- 10 phase folders (01_Start_DB through 10_Disable_Firewall, plus an optional Integrated SOA Gateway step)
- `expect`-driven password prompting — zero manual typing after the env file is set
- Sudoers drop-in so `oracle` can run the 3 root phases via a single driver
- Full manual in a parallel MANUAL path for anyone who wants to understand each step
- Credentials table and "why APPS stays `apps`" gotcha documented upfront

Repo (MIT-licensed): <YOUR_GITHUB_URL>

Next: I'm extending the same "step folder + sample + README" pattern to every EBS technical track — PL/SQL, Concurrent Programs, BI Publisher, WebADI, OAF, Workflow, AD utilities, FNDLOAD, XDOLoader, ...

If you've spent a weekend configuring a Vision VM — this is for you.

#OracleEBS #EBSR12 #Automation #OracleVM #Bash

---

---

## Option C — Arabic version

```text
هل سبق وقمت بإعداد Oracle EBS R12.2 Vision VM للتطوير؟

ساعات من الإعدادات اليدوية:
تشغيل enableSYSADMIN، تفعيل مستخدمي الـ Demo، تغيير كلمات مرور الـ DB schemas، تعديل sqlnet_ifile.ora، تدوير كلمة مرور WebLogic، ثم تعطيل الـ firewall…
كل خطوة بـ prompts تفاعلية يجب التعامل معها واحدة تلو الأخرى.

قمت بأتمتة العملية بالكامل:

- 10 مراحل منفصلة، كل مرحلة في مجلد خاص (README + run.sh)
- Bash + expect scripts تتعامل مع الـ prompts تلقائياً
- ملف إعدادات واحد (ebs_setup.env) يحتوي على كل القيم
- Sudoers drop-in لتشغيل phases الـ root بدون كلمة مرور
- Preflight script للتحقق من الإعدادات قبل التشغيل
- الوقت الكلي: ~25 دقيقة بدلاً من 2+ ساعات يدوي

كل شيء موثق خطوة بخطوة + troubleshooting للأخطاء الشائعة — زي الـ WebLogic password typo trap اللي بيخسرك الـ progress كله لو غلطت في الـ prompt.

المشروع على GitHub:
https://github.com/mohmmedhdx-cloud/ebs-r12-technical-dev

المرحلة القادمة: توسيع نفس النمط (مجلد + README + sample) لباقي مجالات EBS Technical Development — PL/SQL, Concurrent Programs, BI Publisher, WebADI, OAF, Workflow, FNDLOAD, XDOLoader وغيرها.

لو أنت من EBS developers — يُسعدني رأيك وملاحظاتك.

#OracleEBS #EBSR12 #Oracle #Bash #Automation #OracleDatabase #DevOps
```

---

## Option D — Short & casual (~90 words)

```text
Setting up an Oracle EBS R12.2 Vision VM for the first time is... a lot.

enableSYSADMIN, enableDEMOusers, changeDBpasswords, edit sqlnet, rotate the WebLogic password, disable firewalld — a dozen interactive prompts you type by hand. One typo on the WebLogic step and you start over.

So I automated it.

- 10 phases, one folder each
- bash + expect, zero manual typing
- single config file, ~25 minutes end-to-end
- works on a fresh Vision OVA out of the box

https://github.com/mohmmedhdx-cloud/ebs-r12-technical-dev

If you've lost a weekend on this — grab it.

#OracleEBS #EBSR12 #Oracle #Automation
```

---

## Posting tips

1. Pick **one** option above (A if you want quick traction, B if you want signal).
2. Paste into LinkedIn's "Start a post" box.
3. Replace `<YOUR_GITHUB_URL>` with the real repo URL after you push (see [PUBLISHING_TO_GITHUB.md](PUBLISHING_TO_GITHUB.md)).
4. Add 1-2 screenshots if possible:
   - The EBS login page in your browser
   - The terminal showing `./00_run_all.sh` running or the final "All phases complete" banner
5. Post mid-week (Tue-Thu, 9-11 AM local time) for best reach.
6. Respond to every comment in the first 2 hours — LinkedIn's algorithm rewards early engagement.
