#!/bin/bash
# Bookmark - Save articles to readitlater Git repository
# Usage: bookmark.sh <url>

set -e

URL="$1"

if [ -z "$URL" ]; then
    echo "Usage: bookmark.sh <url>"
    exit 1
fi

FETCH_SCRIPT="$HOME/.openclaw/workspace/skills/fetch-skill/scripts/fetch.py"
OUTPUT_DIR="$HOME/Obsidian/readitlater"

# Step 1: Fetch content
echo "[1/4] Fetching content..."

# Detect URL type and use appropriate fetch mode
if echo "$URL" | grep -q "mp.weixin.qq.com"; then
    # WeChat articles: use wespy backend (bypasses CAPTCHA)
    TEMP_FILE=$(mktemp /tmp/bookmark_wechat.XXXXXX.md)
    python3 "$FETCH_SCRIPT" "$URL" -m wechat -o "$TEMP_FILE" 2>/dev/null
    CONTENT=$(cat "$TEMP_FILE")
    rm -f "$TEMP_FILE"
elif echo "$URL" | grep -qE "reddit\.com|old\.reddit\.com"; then
    # Reddit: resolve short links (/s/), then use JSON endpoint
    # First resolve share links to get the real comments URL
    REAL_URL=$(curl -sI -L -H "User-Agent: Mozilla/5.0 (compatible; bookmark/1.0)" "$URL" 2>/dev/null \
        | grep -i "^location:" | head -1 | sed 's/^location: *//;s/\r//')
    if [ -n "$REAL_URL" ]; then
        # Strip query params from resolved URL
        REAL_URL=$(echo "$REAL_URL" | sed 's/?.*//')
    else
        REAL_URL="$URL"
    fi

    TEMP_FILE=$(mktemp /tmp/bookmark_reddit.XXXXXX.json)
    # Build JSON URL from the real comments URL
    JSON_URL=$(echo "$REAL_URL" | sed 's|www\.reddit|old.reddit|')
    # Remove any trailing .json to avoid double
    JSON_URL="${JSON_URL%.json}"
    curl -s -H "User-Agent: Mozilla/5.0 (compatible; bookmark/1.0)" "${JSON_URL}.json" -o "$TEMP_FILE" 2>/dev/null

    CONTENT=$(python3 -c "
import json, sys, html, re
try:
    with open('$TEMP_FILE') as f:
        data = json.load(f)
    post = data[0]['data']['children'][0]['data']
    selftext = html.unescape(post.get('selftext',''))
    title = post['title']
    author = post.get('author','')
    subreddit = post.get('subreddit','')
    score = post.get('score',0)
    num_comments = post.get('num_comments',0)

    output = []
    output.append(f'# {title}')
    output.append(f'')
    output.append(f'**Source:** https://www.reddit.com/r/{subreddit}/comments/{post[\"id\"]}/')
    output.append(f'**Author:** {author} | **Score:** {score} | **Comments:** {num_comments}')
    output.append(f'**Tags:** #reddit #{subreddit}')
    output.append(f'')
    output.append(f'---')
    output.append(f'')
    output.append(selftext)
    output.append(f'')
    output.append(f'---')
    output.append(f'')
    output.append(f'## Top Comments')
    for c in data[1]['data']['children'][:10]:
        if c['kind'] == 't1':
            cd = c['data']
            output.append(f'- **{cd[\"author\"]}** ({cd[\"score\"]}⬆): {cd[\"body\"][:300]}')
            output.append(f'')

    print('\n'.join(output))
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)
    rm -f "$TEMP_FILE"
else
    # General web: use text mode
    CONTENT=$(python3 "$FETCH_SCRIPT" "$URL" -t 2>/dev/null)
fi

if [ -z "$CONTENT" ]; then
    echo "Error: Failed to fetch content"
    exit 1
fi

# Step 2: Extract metadata
echo "[2/4] Extracting metadata..."

# Try frontmatter style first (fetch.py output)
TITLE=$(echo "$CONTENT" | grep -m1 "^title:" | sed 's/^title: *//;s/^"//;s/"$//')
AUTHOR=$(echo "$CONTENT" | grep -m1 "^author:" | sed 's/^author: *//;s/^"//;s/"$//')
SITE=$(echo "$CONTENT" | grep -m1 "^site:" | sed 's/^site: *//;s/^"//;s/"$//')

# Fallback: extract from markdown heading (# Title) or **作者** line
if [ -z "$TITLE" ]; then
    TITLE=$(echo "$CONTENT" | grep -m1 "^# " | sed 's/^# //')
fi
if [ -z "$AUTHOR" ]; then
    AUTHOR=$(echo "$CONTENT" | grep -m1 "^\*\*作者\*\*:" | sed 's/^\*\*作者\*\*: *//')
fi

# Generate filename from title (preserve Chinese chars or use English)
# For Chinese titles: use first 20 chars
# For English titles: lowercase and replace spaces
if echo "$TITLE" | grep -qP '[\x{4e00}-\x{9fff}]'; then
    # Chinese title - keep original chars, remove special chars
    SLUG=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]//g' | cut -c1-30)
else
    # English title
    SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g; s/[^a-z0-9-]//g' | cut -c1-50)
fi
FILENAME="${SLUG}.md"
FILEPATH="$OUTPUT_DIR/$FILENAME"

# Current date
DATE_SAVED=$(date +%Y-%m-%d)

# Step 3: Create markdown file
echo "[3/4] Creating markdown file..."

# Check if content already has proper markdown formatting (wechat-fetcher output)
if echo "$CONTENT" | head -5 | grep -q "^# "; then
    # Already formatted markdown (from wechat/reddit fetcher) — save as-is
    echo "$CONTENT" > "$FILEPATH"
else
    # Wrap in bookmark template
    BODY=$(echo "$CONTENT" | awk '/^---$/{n++;next} n>=2')

    cat > "$FILEPATH" << HEREDOC
---
title: "$TITLE"
source: $URL
author: $AUTHOR
site: $SITE
date_saved: $DATE_SAVED
tags: []
---

# $TITLE

## Abstract

{摘要待补充}

## Original Content

$BODY
HEREDOC
fi

echo "Created: $FILEPATH"

# Step 4: Git commit & push
echo "[4/4] Committing to Git..."
cd "$OUTPUT_DIR"
git add "$FILENAME"
git commit -m "Add: $TITLE"
git pull --rebase --quiet || true
git push

echo ""
echo "✅ Saved to readitlater: $FILENAME"
