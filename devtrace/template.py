import re
from collections import Counter
from datetime import datetime
from pathlib import Path

from slugify import slugify as slugify_fn


SECTIONS = [
    "errors",
    "context",
    "problem",
    "investigation",
    "root-cause",
    "solution",
    "insight",
    "gotchas",
]

SECTION_HEADERS = {
    "errors": "## Errors",
    "context": "## Context",
    "problem": "## Problem",
    "investigation": "## Investigation",
    "root-cause": "## Root Cause",
    "solution": "## Solution",
    "insight": "## Insight",
    "gotchas": "## Gotchas",
}


def generate_template(title):
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    sections = "\n\n".join(
        f"{SECTION_HEADERS[s]}\n\n-" for s in SECTIONS
    )

    return f"""# [WIP] {title}

Date: {now}
Status: In Progress

{sections}
"""


def generate_retro_template(title, past_context):
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    context_block = past_context.strip() if past_context else "-"

    return f"""# [WIP] {title}

Date: {now}
Status: In Progress
Mode: Retroactive

## Errors

-

## Context

{context_block}

## Problem

-

## Investigation

-

## Root Cause

-

## Solution

-

## Insight

-

## Gotchas

-
"""


def export_blog(title, content, date=None, tags=None):
    """Convert session log to blog-ready markdown with frontmatter."""
    now = date or datetime.now().strftime("%Y-%m-%d")
    tags_str = tags or "debugging"

    blog_content = f"""---
title: "{title}"
date: {now}
type: codelog
tags: [{tags_str}]
commits: 
hours: 
status: done
---

{content}
"""
    return blog_content


def _parse_frontmatter(front):
    meta = {}
    for line in front.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, _, value = line.partition(":")
        meta[key.strip().lower()] = value.strip().strip("\"'")
    return meta


def parse_session(path):
    """Parse a session markdown file into structured data."""
    content = Path(path).read_text(encoding="utf-8")

    meta = {}
    text = content
    if content.lstrip().startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            meta = _parse_frontmatter(parts[1])
            text = parts[2]

    title = None
    date = meta.get("date")
    status = meta.get("status")

    sections = {}
    section_order = []
    current = None
    timeline = []

    for raw in text.split("\n"):
        line = raw.rstrip()
        m = re.match(r"^##\s+(.+)$", line)
        if m:
            current = m.group(1).strip()
            sections[current] = []
            section_order.append(current)
            continue
        if current is None:
            h = re.match(r"^#\s+(?:\[[^\]]*\]\s*)?(.+)$", line)
            if h and title is None:
                title = h.group(1).strip()
            elif re.match(r"^Date:\s*", line) and not date:
                date = line.split(":", 1)[1].strip()
            elif re.match(r"^Status:\s*", line) and not status:
                status = line.split(":", 1)[1].strip()
            else:
                t = re.match(r"^-\s+\[(\d{2}:\d{2}:\d{2})\]\s+(.+)$", line)
                if t:
                    timeline.append({"time": t.group(1), "message": t.group(2)})
            continue
        sections[current].append(line)

    errors = []
    for line in sections.get("Errors", []):
        m = re.match(r"^-\s+\[(\d{2}:\d{2}:\d{2})\]\s+`(.*)`\s*$", line)
        if m:
            errors.append({"time": m.group(1), "message": m.group(2), "location": None, "extra": []})
        else:
            loc = re.match(r"^\s*-\s+Location:\s*(.+)$", line)
            if loc and errors:
                errors[-1]["location"] = loc.group(1).strip()
            elif errors and line.strip():
                errors[-1]["extra"].append(line.strip())

    cleaned = {}
    for name in section_order:
        if name in ("Errors", "Work Log"):
            continue
        items = [ln for ln in sections[name] if ln.strip() not in ("", "-", "None", "...")]
        if items:
            cleaned[name] = items

    for line in sections.get("Work Log", []):
        m = re.match(r"^-\s+\[(\d{2}:\d{2}:\d{2})\]\s+(.+)$", line)
        if m:
            timeline.append({"time": m.group(1), "message": m.group(2)})

    return {
        "title": title,
        "date": date,
        "status": status,
        "errors": errors,
        "sections": cleaned,
        "timeline": timeline,
    }


def categorize_error(message):
    """Classify an error message into a category via regex."""
    patterns = [
        (re.compile(r"\bKeyError\b"), "KeyError"),
        (re.compile(r"\bTypeError\b"), "TypeError"),
        (re.compile(r"\bAttributeError\b"), "AttributeError"),
        (re.compile(r"\bValueError\b"), "ValueError"),
        (re.compile(r"\bFileNotFoundError\b"), "FileNotFoundError"),
        (re.compile(r"\bModuleNotFoundError\b|\bImportError\b"), "ImportError"),
        (re.compile(r"\bPermissionError\b"), "PermissionError"),
        (re.compile(r"\bIndexError\b"), "IndexError"),
        (re.compile(r"\bRuntimeError\b"), "RuntimeError"),
        (re.compile(r"\bSyntaxError\b"), "SyntaxError"),
        (re.compile(r"\bConnectionError\b|\bTimeoutError\b|\bConnectionRefusedError\b"), "Network"),
        (re.compile(r"\b(?:4\d\d|5\d\d)\b"), "HTTP"),
    ]
    for pattern, category in patterns:
        if pattern.search(message):
            return category
    return "other"


def generate_blog(data, extra_tags=None):
    """Generate blog-ready markdown from parsed session data (no AI).

    Returns None when the session has no content at all (no errors, no
    timeline, no filled sections) so the caller can skip it.
    """
    title = data.get("title") or "Untitled session"
    date = data.get("date") or datetime.now().strftime("%Y-%m-%d")
    errors = data.get("errors", [])
    sections = data.get("sections", {})
    timeline = data.get("timeline", [])

    if not errors and not timeline and not sections:
        return None

    categories = Counter(categorize_error(e["message"]) for e in errors if e.get("message"))

    tags = set()
    if categories:
        tags.update(slugify_fn(cat) for cat, _ in categories.most_common(3))
    else:
        tags.add("feature")
    if extra_tags:
        for t in extra_tags.split(","):
            t = t.strip().lower()
            if t:
                tags.add(t)
    tags_str = ", ".join(sorted(tags))

    errors_ordered = sorted(errors, key=lambda e: e.get("time") or "")
    timeline_ordered = sorted(timeline, key=lambda t: t.get("time") or "")

    if errors:
        top = categories.most_common(1)[0][0]
        overview = f"Session '{title}' pada {date} - {len(errors)} error tercatat, masalah utama: {top}."
    elif timeline:
        overview = f"Session '{title}' pada {date} - {len(timeline)} langkah aktivitas tercatat."
    else:
        overview = f"Session '{title}' pada {date} - sesi pengembangan."

    body = [f"# {title}", "", overview, ""]

    if errors_ordered:
        body.append("## Errors")
        body.append("")
        for e in errors_ordered:
            item = f"- [{e['time']}] `{e['message']}`"
            if e.get("location"):
                item += f"\n  - Location: {e['location']}"
            for extra in e.get("extra", []):
                item += f"\n  - {extra}"
            body.append(item)
        body.append("")

    if timeline_ordered:
        body.append("## Work Log")
        body.append("")
        for t in timeline_ordered:
            body.append(f"- [{t['time']}] {t['message']}")
        body.append("")

    for key in SECTIONS:
        if key == "errors":
            continue
        name = SECTION_HEADERS[key].replace("## ", "")
        if name in sections:
            body.append(SECTION_HEADERS[key])
            body.append("")
            body.extend(sections[name])
            body.append("")

    body.append("## Stats")
    body.append("")
    body.append(f"- Total errors: {len(errors)}")
    if timeline:
        body.append(f"- Langkah aktivitas: {len(timeline)}")
    if categories:
        breakdown = ", ".join(f"{cat}: {n}" for cat, n in categories.most_common())
        body.append(f"- Kategori: {breakdown}")
    times = [e["time"] for e in errors_ordered if e.get("time")] or [t["time"] for t in timeline_ordered if t.get("time")]
    if len(times) >= 2:
        body.append(f"- Rentang waktu: {times[0]} -> {times[-1]}")
    body.append("")

    content = "\n".join(body).rstrip() + "\n"
    return export_blog(title, content, date=date, tags=tags_str)
