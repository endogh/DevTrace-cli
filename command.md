# Install DevTrace CLI on Another Computer

## Prerequisites

- Python 3.7+ installed
- Git installed
- pip available

---

## Option 1: Automatic Install via Script (Recommended)

> **Tips:** install.sh mengikuti venv — kalau ada venv aktif (`$VIRTUAL_ENV`) atau `.venv/` di proyek, devtrace ikut terpasang di sana. Sebelum install, script menampilkan ringkasan lalu meminta konfirmasi. Untuk non-interaktif, tambahkan `-y` (Windows: `-Yes`).

### Linux / macOS

```bash
curl -sSL https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.sh | bash
```

Non-interaktif (skip konfirmasi):

```bash
curl -sSL https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.sh | bash -s -- -y
```

Or clone and run manually:

```bash
git clone https://github.com/endogh/DevTrace-cli.git
cd DevTrace-cli
bash install.sh
```

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.ps1" -OutFile "$env:TEMP\install.ps1"; & "$env:TEMP\install.ps1"
```

Non-interaktif:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/install.ps1" -OutFile "$env:TEMP\install.ps1"; & "$env:TEMP\install.ps1" -Yes
```

Or clone and run manually:

```powershell
git clone https://github.com/endogh/DevTrace-cli.git
cd DevTrace-cli
.\install.ps1
```

---

## Option 2: Global Install (system-wide)

### Linux/macOS

```bash
bash install.sh -g
```

Or manually:

```bash
git clone https://github.com/endogh/DevTrace-cli.git
cd DevTrace-cli
pip install -e .
```

### Windows

```powershell
.\install.ps1 -Global
```

Or manually:

```powershell
git clone https://github.com/endogh/DevTrace-cli.git
cd DevTrace-cli
pip install -e .
```

---

## Option 3: Manual Install (venv)

1. Clone the repo:

```bash
git clone https://github.com/endogh/DevTrace-cli.git
cd DevTrace-cli
```

2. Create and activate a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate   # Linux/macOS
# or
venv\Scripts\activate      # Windows
```

3. Install devtrace:

```bash
pip install -e .
```

4. Set up directories and shell hook:

```bash
mkdir -p ~/.devtrace
cp devtrace-hook.sh ~/.devtrace/
echo 'source ~/.devtrace/devtrace-hook.sh' >> ~/.bashrc
source ~/.bashrc
```

On Windows, copy `devtrace-hook.ps1` to `~/.devtrace/` and add to your PowerShell profile.

---

## Verify Installation

```bash
devtrace --version
```

Expected output:

```
DevTrace CLI version: 0.17.1
```

---

## Update Existing Installation

```bash
devtrace update
```

This upgrades the DevTrace CLI package to the latest version. It auto-detects how DevTrace was installed (venv, pipx, or pip) and runs the correct upgrade command.

To also refresh the shell hooks in `~/.devtrace/`:

```bash
devtrace upgrade
```

---

## Quick Start

```bash
devtrace start fix-bug
devtrace log "Implemented login validation"
devtrace done
```

---

## Export Blog (no AI)

Generate blog-ready markdown from a session — no AI, purely structured from your logged data (frontmatter, overview, errors, work log, filled sections, and stats).

- **Session debugging** → `## Errors` + kategori error sebagai tag.
- **Session fitur (tanpa error)** → tag `feature` + `## Work Log` dari timeline `devtrace log` + section terisi.
- **Session kosong** (tanpa error/timeline/section) → di-skip dengan warning.

```bash
devtrace export              # 1 session → langsung; banyak session → pilih nomor (a=all)
devtrace export fix-bug      # session tertentu
devtrace export --tags "postgres,perf"
devtrace export --output blog
```

Output default di `blog/<slug>.md`. Tags otomatis diambil dari kategori error (`KeyError`, `HTTP`, dll) atau `feature` saat tanpa error, + bisa ditambah manual via `--tags`. Cek hasilnya lalu upload:

```bash
devtrace upload blog/fix-bug.md
```