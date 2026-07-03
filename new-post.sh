#!/bin/bash

# Script to scaffold a new Hugo blog post with front matter

echo "📝 New Blog Post Scaffolder"
echo "=========================="
echo ""

# Title (required)
read -p "Title: " title
if [ -z "$title" ]; then
  echo "❌ Title is required. Exiting."
  exit 1
fi

# Slug (default: slugified title)
default_slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
read -p "Slug [$default_slug]: " slug
slug=${slug:-$default_slug}

# Author (default: Todd Sharp)
read -p "Author [Todd Sharp]: " author
author=${author:-"Todd Sharp"}

# Date (default: now in ISO 8601)
default_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
read -p "Date [$default_date]: " post_date
post_date=${post_date:-$default_date}

# Summary
read -p "Summary: " summary

# Tags (comma-separated)
read -p "Tags (comma-separated, e.g. aws, livestreaming): " tags_input
if [ -n "$tags_input" ]; then
  # Convert comma-separated to YAML array format
  tags=$(echo "$tags_input" | sed 's/,/","/g' | sed 's/^ *//' | sed 's/ *$//' | sed 's/" /"/g')
  tags="[\"$tags\"]"
else
  tags="[]"
fi

# Keywords (optional)
read -p "Keywords (optional, comma-separated): " keywords

# Canonical URL (optional)
read -p "Canonical URL (optional): " canonical_url

# Featured Image (optional)
read -p "Featured Image URL (optional): " featuredimage

# Build the file path
filename="content/posts/${slug}.md"

# Check if file already exists
if [ -f "$filename" ]; then
  echo ""
  echo "⚠️  File already exists: $filename"
  read -p "Overwrite? (y/N): " overwrite
  if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
    echo "Exiting without creating file."
    exit 0
  fi
fi

# Build front matter
{
  echo "---"
  echo "title: \"$(echo "$title" | sed 's/"/\\"/g')\""
  echo "slug: \"$slug\""
  echo "author: \"$author\""
  echo "date: $post_date"
  if [ -n "$summary" ]; then
    echo "summary: \"$(echo "$summary" | sed 's/"/\\"/g')\""
  fi
  echo "tags: $tags"
  if [ -n "$keywords" ]; then
    echo "keywords: \"$keywords\""
  fi
  if [ -n "$canonical_url" ]; then
    echo "canonical_url: \"$canonical_url\""
  fi
  if [ -n "$featuredimage" ]; then
    echo "featuredimage: \"$featuredimage\""
  fi
  echo "---"
  echo ""
  echo ""
} > "$filename"

echo ""
echo "✅ Post created: $filename"
echo ""
echo "Happy writing! 🚀"
