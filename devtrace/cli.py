import click
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import colorama
from slugify import slugify as slugify_fn
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.markdown import Markdown as RichMarkdown

from devtrace.template import generate_template, generate_retro_template, export_blog, SECTIONS, SECTION_HEADERS

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


def append_to_section(filepath: Path, section: str, message: str):
    content = filepath.read_text(encoding="utf-8")
    lines = content.split("\n")
    now = datetime.now().strftime("%H:%M:%S")

    section_line = find_section_position(content, section)
    if section_line is None:
        return False

    insert_pos = section_line + 1
    while insert_pos < len(lines) and lines[insert_pos].strip() == "":
        insert_pos += 1

    if insert_pos < len(lines) and lines[insert_pos].strip() == "-":
        lines[insert_pos] = f"- [{now}] {message}"
    else:
        lines.insert(insert_pos, f"- [{now}] {message}")

    filepath.write_text("\n".join(lines), encoding="utf-8")
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
def start(name):
    """Start new dev session"""
    session_file = get_session_file(name)

    if session_file.exists():
        click.echo(f"[!] Session '{name}' already exists")
    else:
        session_file.write_text(generate_template(name), encoding="utf-8")

    set_active_session(name)
    click.echo(f"[+] Started session: {name}")


# =========================
# RETROACTIVE START
# =========================

@app.command()
@click.argument("name")
def retro(name):
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
        generate_retro_template(name, past_context),
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
    """Stop session and auto-export to blog-ready markdown"""
    session = get_active_session()

    if not session:
        click.echo("[!] No active session")
        return

    session_file = get_session_file(session)
    content = session_file.read_text(encoding="utf-8")
    content = content.replace("[WIP]", "[DONE]").replace("Status: In Progress", "Status: Done")
    session_file.write_text(content, encoding="utf-8")

    clear_session()
    console.print(f"[bold green][+][/] Stopped session: {session}")

    output = export_blog(session, content)
    output_file = DEVTRACE_DIR / f"{session}-blog.md"
    output_file.write_text(output, encoding="utf-8")
    console.print(f"[bold green][+][/] Exported to: {output_file}")


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
@click.option("--section", "-s", type=click.Choice(SECTIONS), help="Log to specific section")
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
        with open(session_file, "a", encoding="utf-8") as f:
            f.write(f"- [{now}] {message}\n")
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
# EXPORT SESSION
# =========================

@app.command()
@click.argument("name")
@click.option("--format", "-f", type=click.Choice(["blog", "raw"]), default="blog", help="Export format")
def export(name, format):
    """Export session as blog-ready markdown"""
    session_file = get_session_file(name)

    if not session_file.exists():
        click.echo(f"[!] Session '{name}' not found")
        return

    content = session_file.read_text(encoding="utf-8")

    if format == "blog":
        output = export_blog(name, content)
    else:
        output = content

    output_file = DEVTRACE_DIR / f"{name}-export.md"
    output_file.write_text(output, encoding="utf-8")

    console.print(f"[bold green][+][/] Exported to: {output_file}")


# =========================
# ENTRY POINT
# =========================

if __name__ == "__main__":
    app()
