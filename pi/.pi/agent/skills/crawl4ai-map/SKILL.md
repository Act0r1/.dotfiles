---
name: crawl4ai-map
description: Discover URLs and subdomains for a website with Crawl4AI DomainMapper using sitemaps, Common Crawl, certificate transparency, Wayback, robots, feeds, homepage links, and path probing.
compatibility: Requires Crawl4AI 0.9.2 installed through the global uv tool.
---

# Crawl4AI domain map

Map a domain before deciding which pages to crawl. Mapping discovers URLs without rendering every page.

## Output policy

Store generated files in `$HOME/.config/crawl4ai/outputs/`, never in the current project unless requested.

```bash
[ -d "$HOME/.config/crawl4ai/outputs" ] || mkdir -p "$HOME/.config/crawl4ai/outputs"
```

## Fast map

```bash
"$HOME/.pi/agent/skills/crawl4ai-map/scripts/map-domain" \
  "example.com" \
  --source "sitemap+cc" \
  --no-head \
  --max-urls 500 \
  --format urls \
  --output "$HOME/.config/crawl4ai/outputs/example-urls.txt"
```

## Full domain map

```bash
"$HOME/.pi/agent/skills/crawl4ai-map/scripts/map-domain" \
  "example.com" \
  --source "sitemap+cc+wayback+crt+probe+robots+feed+homepage" \
  --max-urls 1000 \
  --format json \
  --output "$HOME/.config/crawl4ai/outputs/example-map.json"
```

## Find relevant pages

```bash
"$HOME/.pi/agent/skills/crawl4ai-map/scripts/map-domain" \
  "example.com" \
  --query "authentication OAuth API" \
  --score-threshold 0.2 \
  --max-urls 100 \
  --format json \
  --output "$HOME/.config/crawl4ai/outputs/example-auth-map.json"
```

## Options

- `--source`: sources joined with `+`; supported values are `sitemap`, `cc`, `wayback`, `crt`, `probe`, `robots`, `feed`, `homepage`
- `--max-urls N`
- `--query TEXT` and `--score-threshold FLOAT`
- `--no-head` for faster URL-only discovery
- `--no-subdomains` to scan only the exact host
- `--hits-per-sec N` and `--concurrency N`
- `--force` to bypass mapping cache
- `--format json|urls`
- `--output PATH`, required

Use `crawl4ai-scrape` for one selected URL or `crawl4ai-crawl` for a selected site section.
