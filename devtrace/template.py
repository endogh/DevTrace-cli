from datetime import datetime


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


def export_blog(title, content):
    """Convert session log to blog-ready markdown with frontmatter."""
    now = datetime.now().strftime("%Y-%m-%d")

    blog_content = f"""---
title: "{title}"
date: {now}
type: codelog
tags: [debugging]
commits: 
hours: 
status: done
---

{content}
"""
    return blog_content
