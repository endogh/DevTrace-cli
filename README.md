# DevTrace CLI

Track your debugging sessions like a pro. Project-local storage, automatic error capture, and blog-ready exports.

## Features

- **Project-local storage** - Sessions stored in `.devtrace/` per project
- **Automatic error capture** - Shell hook captures errors from terminal
- **Retroactive logging** - Start session after debugging
- **Session switching** - Auto-detect by directory, manual switch available
- **Blog export** - Convert sessions to blog-ready markdown
- **Git-friendly** - Commit your logs with your code

## Installation

```bash
# Install the package
pip install -e .

# Install shell hook (bash/zsh)
echo 'source ~/.devtrace/devtrace-hook.sh' >> ~/.bashrc
source ~/.bashrc

# Or for PowerShell
echo '. ~/.devtrace/devtrace-hook.ps1' >> $PROFILE
. $PROFILE
```

## Usage

### Basic Commands

```bash
# Start a new session
devtrace start fix-login-bug

# Log activity
devtrace log "Found null pointer in auth.py"
devtrace log -s investigation "Checked error logs"
devtrace log -s solution "Added null check"

# Log error (from clipboard)
devtrace error

# Log error (manual)
devtrace error "TypeError: Cannot read property 'map'" --context "auth.py:42"

# Stop session
devtrace stop
```

### Session Management

```bash
# List all sessions
devtrace list

# Show recent sessions
devtrace recent

# Switch session
devtrace switch fix-oauth

# View session content
devtrace view fix-login-bug
```

### Retroactive Start

```bash
# When you forgot to start session
devtrace retro fix-login-bug

# It will prompt for what you did:
> Apa yang sudah kamu kerjakan sebelumnya?
> - Cek error logs
> - Found null pointer in auth.py
> (Enter dua kali untuk selesai)
```

### Export for Blog

```bash
# Export as blog-ready markdown
devtrace export fix-login-bug

# Export raw format
devtrace export fix-login-bug --format raw
```

## Shell Hook Features

The shell hook provides:

1. **Auto-detect project** - Shows active session when you cd to a project
2. **Error capture** - Automatically logs errors from failed commands
3. **Session switching** - cd to different project auto-switches session

### Bash/Zsh

```bash
# Add to ~/.bashrc or ~/.zshrc
source ~/.devtrace/devtrace-hook.sh
```

### PowerShell

```powershell
# Add to $PROFILE
. ~/.devtrace/devtrace-hook.ps1
```

## Project Structure

```
<project>/
├── .devtrace/
│   ├── current.txt           # Active session pointer
│   ├── fix-login-bug.md      # Session 1
│   └── fix-oauth.md          # Session 2
├── .gitignore                # Don't ignore .devtrace/
├── src/
└── ...
```

## Git Workflow

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

## Session Format

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

## Commands Reference

| Command | Description |
|---------|-------------|
| `devtrace start <name>` | Start new session |
| `devtrace retro <name>` | Start retroactive session |
| `devtrace stop` | Stop current session |
| `devtrace switch <name>` | Switch active session |
| `devtrace log -s <section> <msg>` | Log to section |
| `devtrace error [msg]` | Log error (clipboard/manual) |
| `devtrace list` | List all sessions |
| `devtrace recent` | Show recent sessions |
| `devtrace view <name>` | View session content |
| `devtrace export <name>` | Export as blog markdown |

## Sections

- `errors` - Error messages and stack traces
- `context` - Project context, tech stack
- `problem` - Problem description
- `investigation` - Debugging steps
- `root-cause` - Root cause analysis
- `solution` - Solution implemented
- `insight` - Lessons learned
- `gotchas` - Gotchas and warnings

## License

MIT
