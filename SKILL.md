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

**一键执行脚本**（推荐）：

```bash
~/.openclaw/workspace/skills/bookmark/scripts/bookmark.sh "{url}"
```

脚本会自动完成：Fetch → Extract → Create Markdown → Git Push

### 手动流程（备选）

如果脚本不可用，可手动执行：

1. **Fetch content**:
   ```bash
   python3 ~/.openclaw/workspace/skills/fetch-skill/scripts/fetch.py "{url}" -t
   ```

2. **Create markdown file** 到 `~/Obsidian/readitlater/`

3. **Git commit & push**:
   ```bash
   cd ~/Obsidian/readitlater && git add . && git commit -m "Add: {title}" && git pull --rebase && git push
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
