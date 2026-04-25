# Publishing this project to GitHub

Step-by-step guide to get `c:\Users\mk\Desktop\EBS_Technical_Devleopemn` onto GitHub as a public repo so you can share it on LinkedIn.

---

## 0. One-time prerequisites

### 0a. Install Git for Windows
If you don't already have it:
```
https://git-scm.com/download/win
```
Install with defaults. Afterwards, open a fresh PowerShell and verify:
```powershell
git --version
```
Expect something like `git version 2.44.0.windows.1`.

### 0b. Create a GitHub account
If you don't have one: [github.com/signup](https://github.com/signup). Pick a username you're happy with — it becomes part of your repo URL.

### 0c. (Optional but recommended) Install GitHub CLI
Lets you create the repo from the terminal. Skip this if you prefer the web UI.
```
https://cli.github.com/
```

---

## 1. Double-check the project for secrets

**Before pushing anything public**, verify nothing sensitive is in the tree.

Open PowerShell, `cd` to the project, and run:
```powershell
cd c:\Users\mk\Desktop\EBS_Technical_Devleopemn

# Find any .env files (should be only the .example template)
Get-ChildItem -Recurse -Include "ebs_setup.env","*.env" | Where-Object { $_.Name -ne "ebs_setup.env.example" }

# Search for the literal password placeholder (just to confirm it's only in docs)
Select-String -Path *.md,**/*.md -Pattern "password" | Measure-Object | Select-Object Count
```

The first command should return **nothing** — only the `.example` template should exist, not a real `ebs_setup.env`.

The provided `.gitignore` (at the project root) already excludes:
- `**/ebs_setup.env` (plaintext passwords)
- `**/logs/`, `*.log`
- `.claude/`, `memory/` (your local Claude setup)
- `*.ldt`, `*.dmp` (Oracle exports)

If you kept my example passwords (`password`, `Welcome01`, `apps`, `manager`) those are **public demo defaults from Oracle docs** — safe to commit. If you changed any of them, also change them back in the `.example` or mention they're just placeholders.

---

## 2. Create the GitHub repository

### Option A — Web UI (easier first time)
1. Go to [github.com/new](https://github.com/new).
2. **Repository name:** `ebs-r12-technical-dev` (or your preferred name).
3. **Description:** `Oracle EBS R12.2 technical development — per-topic guides + Vision VM post-import automation.`
4. **Visibility:** Public.
5. **Leave** "Initialize this repository with a README" **unchecked** (you already have one).
6. Click **Create repository**.
7. Copy the URL GitHub shows you on the next page — it looks like:
   `https://github.com/<your-username>/ebs-r12-technical-dev.git`

### Option B — GitHub CLI (if you installed `gh`)
```powershell
cd c:\Users\mk\Desktop\EBS_Technical_Devleopemn
gh auth login                                       # first time only
gh repo create ebs-r12-technical-dev --public --source=. --description "Oracle EBS R12.2 technical development — per-topic guides + Vision VM post-import automation"
```
This creates the repo AND configures the remote in one step — you can skip to step 4.

---

## 3. Initialize git locally + first commit

In PowerShell at the project root:

```powershell
cd c:\Users\mk\Desktop\EBS_Technical_Devleopemn

# One-time identity setup (if you've never used git on this machine)
git config --global user.name  "Mohmmed"
git config --global user.email "mohmmedhdx@gmail.com"

# Initialize
git init -b main

# Stage everything (the .gitignore excludes secrets)
git add .

# See what will be committed — scan the list for anything surprising
git status

# If it looks clean, commit
git commit -m "Initial commit: EBS R12 technical dev scaffold + Vision VM automation"
```

If `git status` shows `ebs_setup.env` as staged, **stop** and run `git rm --cached 01_EBS_VM_Appliance_Setup/automation/ebs_setup.env` before committing.

---

## 4. Link to GitHub and push

```powershell
# Replace <your-username> with your real GitHub username
git remote add origin https://github.com/<your-username>/ebs-r12-technical-dev.git
git push -u origin main
```

The first push will prompt for credentials — use your GitHub username + a **personal access token** (not your password). Generate one at [github.com/settings/tokens](https://github.com/settings/tokens) with `repo` scope.

After the push succeeds, refresh your GitHub repo page — you should see all 19 folders + README + LICENSE.

---

## 5. Polish the repo

On the GitHub repo page:

1. **About** (right sidebar) → click the gear →
   - Description: *(the one-liner from step 2)*
   - Website: *(leave empty or your LinkedIn)*
   - Topics: add `oracle-ebs`, `oracle`, `ebs-r12`, `bash`, `automation`, `virtualbox`, `plsql`
2. Consider adding a **LICENSE** file — MIT is the most permissive and common. On GitHub: **Add file → Create new file → name it `LICENSE`** → pick MIT from the template dropdown.
3. Pin the repo on your profile: go to your profile → **Customize your pins** → select the repo.

---

## 6. After every change

For future updates (e.g. you finish `02_PLSQL` with real code samples):

```powershell
cd c:\Users\mk\Desktop\EBS_Technical_Devleopemn
git add .
git commit -m "02_PLSQL: add sample package with FND logging + concurrent-program signature"
git push
```

---

## 7. Share on LinkedIn

Once the repo is live:
1. Open [LINKEDIN_POST.md](LINKEDIN_POST.md).
2. Pick Option A or B.
3. Replace `<YOUR_GITHUB_URL>` with your new repo URL.
4. Take a screenshot of EBS login page + one of your terminal mid-run.
5. Paste into LinkedIn, attach screenshots, post.

That's it — your work is public.
