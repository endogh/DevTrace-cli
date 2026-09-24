import os
import stat
from pathlib import Path

import requests
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

console = Console()

CONFIG_FILE = Path.home() / ".devtrace" / "config.env"


def load_env_file(env_path: Path):
    if not env_path.exists():
        return {}
    env = {}
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                value = value.strip().strip("\"'")
                value = value.split(" #")[0].strip()
                env[key.strip()] = value
    return env


def has_config():
    return bool(
        os.environ.get("API_UPLOAD_TOKEN")
        and os.environ.get("API_UPLOAD_URL")
        or CONFIG_FILE.exists()
        and load_env_file(CONFIG_FILE).get("API_UPLOAD_TOKEN")
        and load_env_file(CONFIG_FILE).get("API_UPLOAD_URL")
    )


def save_config(token: str, api_url: str):
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    content = f"# TOKEN FOR UPLOAD\nAPI_UPLOAD_TOKEN={token}\nAPI_UPLOAD_URL={api_url}\n"
    CONFIG_FILE.write_text(content, encoding="utf-8")

    current = stat.S_IMODE(CONFIG_FILE.stat().st_mode)
    if current & 0o077:
        CONFIG_FILE.chmod(0o600)


def get_config():
    # Resolution order: env vars > ~/.devtrace/config.env > project .env
    global_env = load_env_file(CONFIG_FILE)
    local_env = load_env_file(Path.cwd() / ".env")

    merged = {}
    merged.update(global_env)
    merged.update(local_env)
    for key, value in merged.items():
        os.environ.setdefault(key, value)

    token = os.environ.get("API_UPLOAD_TOKEN")
    api_url = os.environ.get("API_UPLOAD_URL")
    return token, api_url


def upload_files(file_paths, token, api_url):
    headers = {"Authorization": f"Token {token}"}

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Uploading...", total=None)

        files = []
        try:
            for p in file_paths:
                path = Path(p)
                files.append(("file", (path.name, open(path, "rb"), "text/markdown")))

            resp = requests.post(api_url, headers=headers, files=files, timeout=60)
            resp.raise_for_status()
            return resp
        except requests.RequestException as e:
            console.print(f"[bold red][!][/] Upload failed: {e}")
            if hasattr(e, "response") and e.response is not None:
                console.print(f"[dim]Response: {e.response.text}[/dim]")
            raise
        finally:
            for _, f in files:
                f[1].close()
