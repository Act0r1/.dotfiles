---
name: searxng-search
description: Search the web through the local SearXNG service without cloud credits, then save normalized sources as JSON, Markdown, or URL lists. Use when the user needs web search or source discovery and does not already have a URL.
compatibility: Requires the local searxng Docker container on http://127.0.0.1:8888.
---

# Local SearXNG search

Use this as the default web search provider. It queries Brave Search through the official API via local SearXNG and does not consume Firecrawl credits. If Brave returns no results, the helper retries with the local-compatible fallback engine set.

## Output policy

Store results in `$HOME/.config/crawl4ai/outputs/`, never in the current project unless requested.

```bash
[ -d "$HOME/.config/crawl4ai/outputs" ] || mkdir -p "$HOME/.config/crawl4ai/outputs"
```

Always write search results to a file instead of streaming a large response into context.

## Basic search

```bash
"$HOME/.pi/agent/skills/searxng-search/scripts/search" \
  "Crawl4AI documentation" \
  --limit 10 \
  --format json \
  --output "$HOME/.config/crawl4ai/outputs/search-crawl4ai.json"
```

## Research or news

```bash
"$HOME/.pi/agent/skills/searxng-search/scripts/search" \
  "web crawling security" \
  --category news \
  --time-range month \
  --language en \
  --limit 20 \
  --format markdown \
  --output "$HOME/.config/crawl4ai/outputs/search-security.md"
```

## URL-only output

```bash
"$HOME/.pi/agent/skills/searxng-search/scripts/search" \
  "site:docs.example.com authentication" \
  --limit 20 \
  --format urls \
  --output "$HOME/.config/crawl4ai/outputs/search-auth-urls.txt"
```

## Options

- `--limit N`
- `--category general|news|images|videos|science|files|it`, repeatable
- `--engine NAME`, repeatable; otherwise the helper uses `braveapi` and falls back to the curated local-compatible engine set when needed
- `--language CODE`, default `all`
- `--time-range day|month|year`
- `--safe-search 0|1|2`
- `--format json|markdown|urls`
- `--output PATH`, required

After selecting a result, use `crawl4ai-scrape`. For several result URLs, use `crawl4ai-crawl` with a controlled list or scrape them individually. Prefer authoritative primary sources and record URLs used in the answer.

If the local service is stopped, start it with:

```bash
docker start searxng
```
