---
name: bookmark
description: "Save articles, URLs, and content to readitlater Git repository. AUTO-TRIGGER: When user sends ONLY a URL without context (standalone URL message), automatically use this skill. Manual triggers: bm, bookmark, readitlater, save for later, save this. Handles URLs (fetches article via fetch-skill), text content (extracts info), and images (OCR first). Outputs markdown files with title, abstract, tags, and full content to ~/Obsidian/readitlater, then commits and pushes to Git."
---

# Bookmark

Save content to readitlater repository for later reading.

## Trigger Behavior

**Auto-trigger**: When user sends ONLY a URL (no other text/context), automatically use this skill.

**Manual triggers**: `bm`, `bookmark`, `readitlater`, `save for later`, `save this`

**Do NOT trigger**: When URL is part of a question or context (e.g., "帮我看看这篇文章 https://..." → normal conversation)

## Workflow

```
Input → Detect Type → Fetch Content → Extract Info → Create Markdown → Git Commit & Push
```

### Step 1: Detect Input Type

- **URL** → Use fetch-skill (unified fetcher):
  ```bash
  python3 ~/.openclaw/workspace/skills/fetch-skill/scripts/fetch.py "{url}" -t
  ```
  - Automatically detects: web, x.com/twitter, wechat mp
  - Fallback chain: Jina → defuddle → markdown.new → Raw
- **Text content** → Process directly
- **Image** → OCR extract text first, then process as content

### Step 2: Fetch Content via fetch-skill

```bash
python3 ~/.openclaw/workspace/skills/fetch-skill/scripts/fetch.py "{url}" -t
```

Output includes:
- `title` - article title
- `author` / `site` - source info
- `word_count` - content length
- Full markdown content

### Step 3: Extract Information

From the fetched content, extract:
- **title**: Article title (保留源语言，中文标题不翻译)
- **abstract**: 2-3 sentence summary
- **tags**: 3-5 relevant keywords
- **source**: Original URL
- **date_saved**: Current date (YYYY-MM-DD)
- **content**: Full original content from fetch-skill (保留所有图片、视频、多媒体链接)

### Step 4: Create Markdown File

Save to `~/Obsidian/readitlater/` with filename: `{title-slug}.md`

Template:
```markdown
---
title: {title}
source: {url}
author: {author}
date_saved: {YYYY-MM-DD}
tags: [tag1, tag2, tag3]
---

# {title}

## Abstract

{abstract}

## Original Content

{full content from fetch-skill}
```

### Step 5: Git Commit & Push

```bash
cd ~/Obsidian/readitlater
git add .
git commit -m "Add: {title}"
git pull --rebase
git push
```

## File Naming

- Convert title to lowercase, replace spaces with hyphens
- Remove special characters
- Max 50 characters
- Example: "AI Revolution in Healthcare" → `ai-revolution-in-healthcare.md`

## Language

- **标题**: 保留源语言，不翻译。中文标题保持中文，英文标题保持英文
- **正文内容**: 保持原始语言，不翻译
- Chinese content stays Chinese
- English content stays English

## Content Preservation

- **保留所有图片链接**: `![alt](url)` 格式，不删除
- **保留视频/多媒体**: iframe、视频链接等全部保留
- **保留原始格式**: 不简化或摘除任何媒体元素

## Dependencies

- **fetch-skill** - Unified URL fetcher (installed at `~/.openclaw/workspace/skills/fetch-skill/`)
  - Supports: web, Twitter/X, WeChat MP
  - Zero-dependency core for basic fetching
  - Optional: Camofox for Twitter replies/timeline
  - Optional: wechat-article-exporter API for better WeChat support
