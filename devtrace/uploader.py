import os
from pathlib import Path

import requests
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

console = Console()


def load_env():
    env_path = Path.cwd() / ".env"
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


def get_config():
    env = load_env()
    for key, value in env.items():
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
