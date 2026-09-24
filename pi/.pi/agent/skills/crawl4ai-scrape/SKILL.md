---
name: crawl4ai-scrape
description: Extract a known web URL into clean or relevance-filtered Markdown locally with Crawl4AI. Use for static or JavaScript-rendered pages when the user already has a URL.
compatibility: Requires Crawl4AI 0.9.2 and its Playwright browser installed through the global uv tool.
---

# Crawl4AI scrape

Use Crawl4AI locally for a known URL. No Crawl4AI API key or cloud credits are required.

## Output policy

Store generated files in `$HOME/.config/crawl4ai/outputs/`, never in the current project unless the user explicitly requests a project path.

```bash
[ -d "$HOME/.config/crawl4ai/outputs" ] || mkdir -p "$HOME/.config/crawl4ai/outputs"
```

Always use `-O` so large pages do not flood the model context.

## Basic scrape

```bash
crwl crawl "https://example.com" \
  -o markdown \
  -O "$HOME/.config/crawl4ai/outputs/example.md"
```

## Main content

Use fit Markdown to remove navigation and low-value content:

```bash
crwl crawl "https://example.com" \
  -o markdown-fit \
  -O "$HOME/.config/crawl4ai/outputs/example-fit.md"
```

For query-focused filtering, create a YAML filter in the output directory:

```yaml
type: bm25
query: authentication configuration
threshold: 1.0
```

```bash
crwl crawl "https://example.com" \
  -f "$HOME/.config/crawl4ai/outputs/filter.yml" \
  -o markdown-fit \
  -O "$HOME/.config/crawl4ai/outputs/example-auth.md"
```

## Dynamic pages

```bash
crwl crawl "https://example.com" \
  -c "wait_for=css:.main-content,scan_full_page=true,page_timeout=60000" \
  -o markdown \
  -O "$HOME/.config/crawl4ai/outputs/example-dynamic.md"
```

Use `crawl4ai-interact` when clicks, forms, persistent sessions, or custom JavaScript are required.

## Reading results

Use `grep` and incremental reads. Do not load a large output file in one call.
