import click
import importlib.metadata
import os
import re
import site
import subprocess
import sys
import sysconfig
from datetime import datetime
from pathlib import Path
from . import __version__

import colorama
from slugify import slugify as slugify_fn
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.markdown import Markdown as RichMarkdown

from devtrace.template import (
    generate_template,
    generate_retro_template,
    export_blog,
    parse_session,
    generate_blog,
    SECTIONS,
    ALL_SECTIONS,
    SECTION_HEADERS,
)

colorama.just_fix_windows_console()
console = Console()

DEVTRACE_DIR = Path.cwd() / ".devtrace"
SESSION_FILE = DEVTRACE_DIR / "current.txt"


def ensure_dir():
    DEVTRACE_DIR.mkdir(parents=True, exist_ok=True)


def get_active_session():
    if SESSION_FILE.exists():
        return SESSION_FILE.read_text().strip()
    return None


def set_active_session(name: str):
    SESSION_FILE.write_text(name)


def clear_session():
    if SESSION_FILE.exists():
        SESSION_FILE.unlink()


def get_session_file(name: str):
    return DEVTRACE_DIR / f"{name}.md"


def make_slug(name: str):
    return slugify_fn(name)


def list_sessions():
    ensure_dir()
    sessions = []
    for f in sorted(DEVTRACE_DIR.glob("*.md")):
        name = f.stem
        is_active = name == get_active_session()
        mtime = datetime.fromtimestamp(f.stat().st_mtime)
        sessions.append((name, is_active, mtime))
    return sessions


def find_section_position(content: str, section: str):
    pattern = rf"^## {re.escape(SECTION_HEADERS[section].replace('## ', ''))}$"
    for i, line in enumerate(content.split("\n")):
        if re.match(pattern, line, re.MULTILINE):
            return i
    return None


def insert_after_header(content: str, header: str, entry: str):
    """Insert entry right after a '## header' line, replacing a lone '-' placeholder."""
    lines = content.split("\n")
    for i, line in enumerate(lines):
        if line.strip() == header:
            insert_pos = i + 1
            while insert_pos < len(lines) and lines[insert_pos].strip() == "":
                insert_pos += 1

            if insert_pos < len(lines) and lines[insert_pos].strip() == "-":
                lines[insert_pos] = entry
            else:
                lines.insert(insert_pos, entry)
            return "\n".join(lines)
    return None


def append_to_section(filepath: Path, section: str, message: str):
    content = filepath.read_text(encoding="utf-8")
    now = datetime.now().strftime("%H:%M:%S")

    new_content = insert_after_header(content, SECTION_HEADERS[section], f"- [{now}] {message}")
    if new_content is None:
        return False

    filepath.write_text(new_content, encoding="utf-8")
    return True


def get_clipboard():
    try:
        if sys.platform == "win32":
            result = subprocess.run(
                ["powershell", "-command", "Get-Clipboard"],
                capture_output=True, text=True, timeout=5
            )
            return result.stdout.strip()
        elif sys.platform == "darwin":
            result = subprocess.run(
                ["pbpaste"], capture_output=True, text=True, timeout=5
            )
            return result.stdout.strip()
        else:
            result = subprocess.run(
                ["xclip", "-selection", "clipboard", "-o"],
                capture_output=True, text=True, timeout=5
            )
            return result.stdout.strip()
    except Exception:
        return None


def show_banner():
    session = get_active_session()
    if session:
        sessions = list_sessions()
        count = len(sessions)
        title = Text("DEVTRACE", style="bold cyan")
        if count > 1:
            body = f"[bold cyan]Active:[/bold cyan] {session}\n[dim]{count} sessions available[/dim]\n[dim]devtrace stop to end session[/dim]"
        else:
            body = f"[bold cyan]Active:[/bold cyan] {session}\n[dim]devtrace stop to end session[/dim]"
        console.print(Panel(body, title=title, border_style="cyan"))


@click.group(invoke_without_command=True)
@click.version_option(version=__version__, prog_name="devtrace CLI")
@click.pass_context
def app(ctx):
    """DevTrace CLI - Track your dev activity like a pro"""
    ensure_dir()
    if ctx.invoked_subcommand is None:
        show_banner()


@app.result_callback()
def after_command(result):
    pass


# =========================
# START SESSION
# =========================

@app.command()
@click.argument("name")
@click.option("--type", "session_type", type=click.Choice(["debug", "feature"]), default="debug", help="Session type: debug or feature")
def start(name, session_type):
    """Start  new  session"""
    session_file = get_session_file(name)

    if session_file.exists():
        click.echo(f"[!] Session '{name}' already exists")
    else:
        session_file.write_text(generate_template(name, session_type), encoding="utf-8")

    set_active_session(name)
    click.echo(f"[+] Started session: {name}")


# =========================
# RETROACTIVE START
# =========================

@app.command()
@click.argument("name")
@click.option("--type", "session_type", type=click.Choice(["debug", "feature"]), default="debug", help="Session type: debug or feature")
def retro(name, session_type):
    """Start session retroactively (for when you forgot to start)"""
    session_file = get_session_file(name)

    if session_file.exists():
        click.echo(f"[!] Session '{name}' already exists")
        return

    click.echo("[?] Apa yang sudah kamu kerjakan sebelumnya?")
    click.echo("    (tekan Enter dua kali untuk selesai)")
    click.echo("")

    lines = []
    empty_count = 0
    while True:
        try:
            line = input("> ")
        except EOFError:
            break

        if line == "":
            empty_count += 1
            if empty_count >= 2:
                break
            lines.append("")
        else:
            empty_count = 0
            lines.append(line)

    past_context = "\n".join(lines) if lines else "-"

    session_file.write_text(
        generate_retro_template(name, past_context, session_type),
        encoding="utf-8"
    )

    set_active_session(name)
    click.echo(f"[+] Started retroactive session: {name}")
    click.echo(f"    File: {session_file}")


# =========================
# STOP SESSION
# =========================

@app.command()
def stop():
    """Stop current session"""
    session = get_active_session()

    if not session:
        click.echo("[!] No active session")
        return

    session_file = get_session_file(session)
    content = session_file.read_text(encoding="utf-8")
    content = content.replace("[WIP]", "[DONE]").replace("Status: In Progress", "Status: Done")
    session_file.write_text(content, encoding="utf-8")

    clear_session()
    click.echo(f"[+] Stopped session: {session}")


# =========================
# DONE (STOP + EXPORT)
# =========================

@app.command()
def done():
    """Stop session and convert to blog-ready markdown (1 file)"""
    session = get_active_session()

    if not session:
        click.echo("[!] No active session")
        return

    session_file = get_session_file(session)
    content = session_file.read_text(encoding="utf-8")
    content = content.replace("[WIP]", "[DONE]").replace("Status: In Progress", "Status: Done")

    blog = export_blog(session, content)
    session_file.write_text(blog, encoding="utf-8")

    clear_session()
    console.print(f"[bold green][+][/] Stopped + blog-ready: {session}")
    console.print(f"[dim]File: {session_file}[/dim]")


# =========================
# SWITCH SESSION
# =========================

@app.command()
@click.argument("name")
def switch(name):
    """Switch active session"""
    session_file = get_session_file(name)

    if not session_file.exists():
        click.echo(f"[!] Session '{name}' not found")
        return

    set_active_session(name)
    click.echo(f"[+] Switched to: {name}")


# =========================
# LOG ERROR
# =========================

@app.command()
@click.argument("message", required=False)
@click.option("--context", "-c", help="Additional context (file:line, etc)")
def error(message, context):
    """Log an error (reads from clipboard if no message provided)"""
    session = get_active_session()

    if not session:
        click.echo("[!] No active session. Start one first:")
        click.echo("    devtrace start <name>")
        click.echo("    devtrace retro <name>")
        return

    if not message:
        click.echo("[*] Reading from clipboard...")
        message = get_clipboard()
        if not message:
            click.echo("[!] Could not read clipboard or clipboard is empty")
            click.echo("    Usage: devtrace error \"error message\"")
            return

    session_file = get_session_file(session)
    now = datetime.now().strftime("%H:%M:%S")

    error_entry = f"- [{now}] `{message}`"
    if context:
        error_entry += f"\n  - Location: {context}"

    content = session_file.read_text(encoding="utf-8")
    lines = content.split("\n")

    section_line = find_section_position(content, "errors")
    if section_line is not None:
        insert_pos = section_line + 1
        while insert_pos < len(lines) and lines[insert_pos].strip() == "":
            insert_pos += 1

        if insert_pos < len(lines) and lines[insert_pos].strip() == "-":
            lines[insert_pos] = error_entry
        else:
            lines.insert(insert_pos, error_entry)

        session_file.write_text("\n".join(lines), encoding="utf-8")
        click.echo(f"[+] Logged error: {message[:50]}...")
    else:
        with open(session_file, "a", encoding="utf-8") as f:
            f.write(f"\n## Errors\n\n{error_entry}\n")
        click.echo(f"[+] Created Errors section and logged: {message[:50]}...")


# =========================
# LOG ACTIVITY
# =========================

@app.command()
@click.argument("message")
@click.option("--section", "-s", type=click.Choice(ALL_SECTIONS), help="Log to specific section")
def log(message, section):
    """Log activity into current session"""
    session = get_active_session()

    if not session:
        if click.confirm("[!] No active session. Start new session?"):
            name = click.prompt("Session name")
            session_file = get_session_file(name)
            if not session_file.exists():
                session_file.write_text(generate_template(name), encoding="utf-8")
            set_active_session(name)
            session = name
            click.echo(f"[+] Started session: {name}")
        else:
            return

    session_file = get_session_file(session)

    if section:
        if append_to_section(session_file, section, message):
            click.echo(f"[+] Logged to {section}: {message}")
        else:
            click.echo(f"[!] Section '{section}' not found")
    else:
        now = datetime.now().strftime("%H:%M:%S")
        entry = f"- [{now}] {message}"
        content = session_file.read_text(encoding="utf-8")
        new_content = insert_after_header(content, "## Work Log", entry)
        if new_content is None:
            with open(session_file, "a", encoding="utf-8") as f:
                f.write(f"\n## Work Log\n\n{entry}\n")
        else:
            session_file.write_text(new_content, encoding="utf-8")
        click.echo(f"[+] Logged: {message}")


# =========================
# STATUS
# =========================

@app.command()
def status():
    """Show current session"""
    session = get_active_session()

    if session:
        click.echo(f"[+] Active session: {session}")
    else:
        click.echo("[!] No active session")


# =========================
# SHOW FILE
# =========================

@app.command()
def show():
    """Show current session file"""
    session = get_active_session()

    if not session:
        click.echo("[!] No active session")
        return

    session_file = get_session_file(session)
    click.echo(f"File: {session_file}")


# =========================
# LIST SESSIONS
# =========================

@app.command("list")
def list_sessions_cmd():
    """List all sessions"""
    from rich.table import Table

    sessions = list_sessions()

    if not sessions:
        click.echo("[!] No sessions found")
        return

    table = Table(title="Sessions", show_header=True, header_style="bold cyan")
    table.add_column("Name")
    table.add_column("Status")
    table.add_column("Modified")

    for name, is_active, mtime in sessions:
        status = "[bold green]ACTIVE[/bold green]" if is_active else ""
        date_str = mtime.strftime("%Y-%m-%d %H:%M")
        table.add_row(name, status, date_str)

    console.print(table)


# =========================
# RECENT SESSIONS
# =========================

@app.command()
@click.option("--count", "-n", default=5, help="Number of recent sessions")
def recent(count):
    """Show recent sessions"""
    from rich.table import Table

    sessions = list_sessions()

    if not sessions:
        click.echo("[!] No sessions found")
        return

    sessions.sort(key=lambda x: x[2], reverse=True)

    table = Table(title=f"Recent {min(count, len(sessions))} sessions", show_header=True, header_style="bold cyan")
    table.add_column("Name")
    table.add_column("Status")
    table.add_column("Modified")

    for name, is_active, mtime in sessions[:count]:
        status = "[bold green]ACTIVE[/bold green]" if is_active else ""
        date_str = mtime.strftime("%Y-%m-%d %H:%M")
        table.add_row(name, status, date_str)

    console.print(table)


# =========================
# VIEW SESSION
# =========================

@app.command()
@click.argument("name")
def view(name):
    """View session content"""
    session_file = get_session_file(name)

    if not session_file.exists():
        click.echo(f"[!] Session '{name}' not found")
        return

    content = session_file.read_text(encoding="utf-8")
    console.print(RichMarkdown(content))


# =========================
# UPLOAD SESSION
# =========================

def list_blog_files():
    ensure_dir()
    files = []
    for f in sorted(DEVTRACE_DIR.glob("*.md")):
        if f.stem in ("current",):
            continue
        files.append(f)
    return files


def pick_blog_files(prompt="Select files to upload (e.g. 1,2,4,6, a=all)"):
    files = list_blog_files()
    if not files:
        click.echo("[!] No files found in .devtrace/")
        return None

    from rich.table import Table
    table = Table(show_header=True, header_style="bold cyan")
    table.add_column("#", style="dim")
    table.add_column("File")
    table.add_column("Modified", style="dim")
    for i, f in enumerate(files, 1):
        mtime = datetime.fromtimestamp(f.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
        table.add_row(str(i), f.name, mtime)
    console.print(table)

    inp = click.prompt(prompt, default="").strip()
    if not inp:
        click.echo("[!] No selection")
        return None

    if inp.lower() in ("a", "all"):
        return files

    selected = []
    for part in inp.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            try:
                a, b = part.split("-")
                for n in range(int(a), int(b) + 1):
                    if 1 <= n <= len(files):
                        selected.append(files[n - 1])
            except ValueError:
                continue
        else:
            try:
                n = int(part)
                if 1 <= n <= len(files):
                    selected.append(files[n - 1])
            except ValueError:
                continue

    if not selected:
        click.echo("[!] No valid selection")
        return None

    return selected


@app.command()
@click.argument("files", nargs=-1)
@click.option("--session", "-s", "session_name", help="Upload a specific session by name")
@click.option("--all", "-a", "all_sessions", is_flag=True, help="Upload all sessions")
def upload(files, session_name, all_sessions):
    """Upload File(s) to API endpoint (configured in .env as TOKEN and API)"""
    from devtrace.uploader import get_config, upload_files

    token, api_url = get_config()
    if not token:
        click.echo("[!] TOKEN not found in .env")
        return
    if not api_url:
        click.echo("[!] API URL not found in .env (set API or API_URL)")
        return

    targets = []

    if files:
        for f in files:
            p = Path(f)
            if p.exists():
                targets.append(p)
            else:
                candidate = DEVTRACE_DIR / f
                if candidate.exists():
                    targets.append(candidate)
                else:
                    click.echo(f"[!] File not found: {f}")
                    return
    elif all_sessions:
        targets = list_blog_files()
        if not targets:
            click.echo("[!] No files found in .devtrace/")
            return
    elif session_name:
        sf = get_session_file(session_name)
        if not sf.exists():
            click.echo(f"[!] Session '{session_name}' not found")
            return
        targets = [sf]
    else:
        picked = pick_blog_files()
        if picked is None:
            return
        targets = picked

    try:
        resp = upload_files(targets, token, api_url)
        console.print(f"[bold green][+][/] Uploaded {len(targets)} file(s) to {api_url}")
        console.print(f"[dim]Status: {resp.status_code}[/dim]")
    except Exception:
        pass


# =========================
# EXPORT BLOG
# =========================

@app.command()
@click.argument("name", required=False)
@click.option("--tags", "extra_tags", help="Extra tags (comma separated)")
@click.option("--output", "-o", "output_dir", default="blog", show_default=True, help="Output directory")
def export(name, extra_tags, output_dir):
    """Generate blog-ready markdown from session(s)"""
    files = list_blog_files()
    if not files:
        click.echo("[!] No files found in .devtrace/")
        return

    if name:
        sf = get_session_file(name)
        if not sf.exists():
            click.echo(f"[!] Session '{name}' not found")
            return
        targets = [sf]
    elif len(files) == 1:
        targets = files
    else:
        picked = pick_blog_files("Select files to export (e.g. 1,2,4,6, a=all)")
        if picked is None:
            return
        targets = picked

    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    for f in targets:
        data = parse_session(f)
        blog = generate_blog(data, extra_tags)
        if blog is None:
            console.print(f"[bold yellow][!][/] Session '{f.stem}' kosong (tanpa error, timeline, atau section terisi) - dilewati")
            continue
        slug = make_slug(data.get("title") or f.stem)
        out = out_dir / f"{slug}.md"
        out.write_text(blog, encoding="utf-8")
        console.print(f"[bold green][+][/] Exported: {out}")


# =========================
# CLEAR BLOG FILES
# =========================

@app.command()
def clear():
    """Remove all blog/session files from .devtrace/"""
    files = list_blog_files()
    if not files:
        click.echo("[!] No files to clear")
        return

    click.echo("Files to remove:")
    for f in files:
        click.echo(f"  - {f.name}")

    if click.confirm("Remove these files?"):
        count = 0
        for f in files:
            f.unlink()
            count += 1
        console.print(f"[bold green][+][/] Removed {count} file(s)")



# =========================
# UPDATE / UPGRADE
# =========================

GITHUB_REPO = "git+https://github.com/endogh/DevTrace-cli.git"
HOOK_BASE_URL = "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/"


def detect_install_mode():
    executable = str(Path(sys.executable).resolve()).lower()
    prefix = str(Path(sys.prefix).resolve()).lower()

    if "pipx" in executable or "pipx" in prefix:
        return "pipx"
    if sys.prefix != sys.base_prefix:
        return "venv"
    if site.getusersitepackages() in sys.path:
        return "user"
    return "system"


def installed_version():
    try:
        return importlib.metadata.version("devtrace")
    except importlib.metadata.PackageNotFoundError:
        return "unknown"


def upgrade_package():
    mode = detect_install_mode()
    before = installed_version()
    console.print(f"[dim]Current version:[/dim] {before}")
    console.print(f"[dim]Install mode:[/dim] {mode}")

    def run_cmd(cmd, hint=None):
        console.print(f"[dim]Running:[/dim] {' '.join(cmd)}")
        try:
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        except FileNotFoundError:
            console.print(f"[bold red][!][/] Command not found: {cmd[0]}")
            return False
        output = proc.stdout or ""
        if output.strip():
            print(output, end="")
        if proc.returncode != 0:
            console.print("[bold red][!][/] Update failed. Check the output above.")
            if hint:
                for line in hint:
                    console.print(line)
            return False
        return True

    if mode == "pipx":
        cmd = ["pipx", "install", "--force", "--pip-args=--force-reinstall", GITHUB_REPO]
        hint = [
            "    Saran untuk mode pipx:",
            "      - pipx upgrade devtrace  (kalau versi sudah lebih baru)",
            "      - atau pipx uninstall devtrace lalu pipx install git+https://github.com/endogh/DevTrace-cli.git",
        ]
        if not run_cmd(cmd, hint):
            return False
    else:
        base = [sys.executable, "-m", "pip", "install"]
        if mode == "user":
            base.append("--user")

        hint = None
        if mode == "system":
            site_dir = sysconfig.get_paths()["purelib"]
            is_root = hasattr(os, "geteuid") and os.geteuid() == 0
            if not os.access(site_dir, os.W_OK) and not is_root:
                console.print("[bold yellow][!][/] Python sistem tidak writable oleh user biasa.")
                console.print("    Saran:")
                console.print(f"      - sudo {sys.executable} -m pip install --upgrade {GITHUB_REPO}")
                console.print("      - atau via pipx:  pipx install --force git+https://github.com/endogh/DevTrace-cli.git")
                return False
            hint = [
                "    Saran untuk mode system:",
                f"      - sudo {sys.executable} -m pip install --upgrade {GITHUB_REPO}",
                "      - atau via pipx:  pipx install --force git+https://github.com/endogh/DevTrace-cli.git",
                "      - atau pakai venv proyek",
            ]
        elif mode == "user":
            hint = [
                "    Saran untuk mode user (PEP 668 / externally-managed?):",
                "      - pip install --upgrade --user --break-system-packages git+https://github.com/endogh/DevTrace-cli.git",
                "      - atau via pipx:  pipx install --force git+https://github.com/endogh/DevTrace-cli.git",
            ]

        if not run_cmd(base + [GITHUB_REPO], hint):
            return False
        if not run_cmd(base + ["--force-reinstall", "--no-deps", GITHUB_REPO], hint):
            return False

    after = installed_version()
    console.print(f"[bold green][+][/] Updated from {before} to {after}")
    return True


def update_hooks():
    devtrace_home = Path.home() / ".devtrace"
    devtrace_home.mkdir(parents=True, exist_ok=True)

    if sys.platform == "win32":
        hook_name = "devtrace-hook.ps1"
    else:
        shell = (os.environ.get("SHELL") or "").rsplit("/", 1)[-1]
        hook_name = "devtrace-hook.fish" if shell == "fish" else "devtrace-hook.sh"

    url = HOOK_BASE_URL + hook_name
    target = devtrace_home / hook_name
    console.print(f"[dim]Downloading {hook_name}...[/dim]")

    try:
        import requests
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        target.write_text(resp.text, encoding="utf-8")
        console.print(f"[bold green][+][/] Hook updated: {target}")
    except Exception as e:
        console.print(f"[bold red][!][/] Could not update hook: {e}")


@app.command()
def update():
    """Update DevTrace CLI package to the latest version"""
    upgrade_package()


@app.command()
def upgrade():
    """Update DevTrace CLI package and refresh shell hooks"""
    if upgrade_package():
        update_hooks()


# =========================
# ENTRY POINT
# =========================

if __name__ == "__main__":
    app()
