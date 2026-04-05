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
CONTENT=$(python3 "$FETCH_SCRIPT" "$URL" -t 2>/dev/null)

if [ -z "$CONTENT" ]; then
    echo "Error: Failed to fetch content"
    exit 1
fi

# Step 2: Extract metadata
echo "[2/4] Extracting metadata..."
TITLE=$(echo "$CONTENT" | grep -m1 "^title:" | sed 's/^title: *//;s/^"//;s/"$//')
AUTHOR=$(echo "$CONTENT" | grep -m1 "^author:" | sed 's/^author: *//;s/^"//;s/"$//')
SITE=$(echo "$CONTENT" | grep -m1 "^site:" | sed 's/^site: *//;s/^"//;s/"$//')

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

# Extract body content (everything after the second ---)
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
