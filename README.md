# 🧠 DevTrace

> Stop losing solutions to bugs you've already solved.

Capture your debugging journey and turn it into a reusable knowledge base.

DevTrace is a CLI tool that helps developers track their coding sessions, log problems in real-time, and convert raw debugging activity into structured, reusable knowledge.

---

## 🤔 Why DevTrace?

Every developer has experienced this:

- You solve a complex bug today
- Tomorrow, you forget how you fixed it
- Next week, you solve the *same problem again*

DevTrace fixes that.

Instead of writing blogs *after* you're done (and forgetting details), DevTrace lets you:

- Log your thinking **while solving the problem**
- Capture real debugging steps
- Build a personal knowledge base automatically

---

## ✨ Features

- 🧾 **Session-based tracking** - Organize by project and problem
- 🧠 **Real-time logging** - Capture thoughts as you debug
- 📄 **Markdown output** - Readable, version-controllable
- ⚡ **Lightweight & fast** - No database, just files
- 🔄 **Auto error capture** - Shell hook catches errors automatically
- 📝 **Retroactive start** - Forgot to start? No problem
- 🌐 **Multi-device sync** - Via git
- 📢 **Blog export** - Convert to blog-ready markdown

---

## 📦 Installation

### Default (venv) — Recommended

Installs in an isolated virtual environment at `~/.devtrace/venv/`.

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.ps1" -OutFile "$env:TEMP\install.ps1"; & "$env:TEMP\install.ps1"
```

### Global Install

Installs system-wide. On Arch/CachyOS this uses `pipx`, on other distros uses `pip`.

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.sh | bash -s -- -g
```

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.ps1" -OutFile "$env:TEMP\install.ps1"; & "$env:TEMP\install.ps1" -Global
```

### Manual Install

```bash
git clone https://github.com/endogh/DevTrace-cli.git
cd DevTrace-cli
pip install -e .

mkdir -p ~/.devtrace
cp devtrace-hook.sh ~/.devtrace/
echo 'source ~/.devtrace/devtrace-hook.sh' >> ~/.bashrc
source ~/.bashrc
```

### Supported Platforms

| OS | Shell | Method |
|----|-------|--------|
| Arch/CachyOS | bash/zsh | `curl \| bash` |
| Ubuntu/Debian | bash/zsh | `curl \| bash` |
| Fedora | bash/zsh | `curl \| bash` |
| macOS | bash/zsh | `curl \| bash` |
| Windows | PowerShell | `install.ps1` |
| Any | Fish | Auto-detect |

---

## 🔄 Updating

```bash
# Upgrade the package only
devtrace update

# Upgrade package + refresh shell hooks in ~/.devtrace/
devtrace upgrade
```

Both auto-detect how DevTrace was installed (venv, pipx, or pip) and run the correct upgrade command.

---

## 🚀 Workflow

```bash
# 1. Start session
devtrace start fix-login-bug

# 2. Work (errors auto-capture from shell hook)
$ npm start
Error: Cannot find module 'xyz'
[DEVTRACE] Logged error: Cannot find module 'xyz'

# 3. Manual logging (optional)
devtrace log -s context "Project: Next.js 14"
devtrace log -s solution "Added null check"

# 4. Done - stop + auto export
devtrace done
```

**Active session banner:**
```
╭───────── DEVTRACE ─────────╮
│ Active: fix-login-bug       │
│ devtrace stop to end session│
╰─────────────────────────────╯
```

**List sessions:**
```
              Sessions              
┏━━━━━━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━┓
┃ Name         ┃ Status ┃ Modified ┃
┡━━━━━━━━━━━━━━╇━━━━━━━━╇━━━━━━━━━━┩
│ fix-login    │ ACTIVE │ 07-23    │
│ fix-oauth    │        │ 07-22    │
└──────────────┴━━━━━━━━┴━━━━━━━━━━┘
```

---

## 📋 Commands

| Command | Description |
|---------|-------------|
| `devtrace start <name>` | Start new session |
| `devtrace retro <name>` | Start retroactive session |
| `devtrace done` | Stop + auto export to blog |
| `devtrace stop` | Stop session only |
| `devtrace switch <name>` | Switch active session |
| `devtrace log -s <section> <msg>` | Log to section |
| `devtrace error [msg]` | Log error (clipboard/manual) |
| `devtrace list` | List all sessions |
| `devtrace recent` | Show recent sessions |
| `devtrace view <name>` | View session content |
| `devtrace export <name>` | Export as blog markdown |
| `devtrace update` | Update package to latest version |
| `devtrace upgrade` | Update package + refresh shell hooks |

---

## 📁 Project Structure

```
<project>/
├── .devtrace/
│   ├── current.txt           # Active session pointer
│   ├── fix-login-bug.md      # Session 1
│   └── fix-oauth.md          # Session 2
├── .gitignore
├── src/
└── ...
```

---

## 📝 Session Format

Each session is a markdown file with structured sections:

```markdown
# [WIP] fix-login-bug

Date: 2026-07-22 14:30
Status: In Progress

## Errors

- [14:30:22] `TypeError: Cannot read property 'map' of undefined`
  - Location: auth.py:42

## Context

- Project: Next.js 14
- Auth: NextAuth.js

## Problem

- Login fails silently after password reset

## Investigation

- Checked error logs
- Found null pointer in auth.py

## Root Cause

- Missing null check before array map

## Solution

- Added null check: `items?.map(...)`

## Insight

- Always use optional chaining for API responses

## Gotchas

- NextAuth.js doesn't validate token structure by default
```

---

## 🔄 Git Workflow

```bash
# Commit logs with your code
git add .devtrace/
git commit -m "log: fix login bug"

# Push to sync across devices
git push

# On another device
git pull
# All logs sync automatically!
```

---

## 📄 License

MIT
