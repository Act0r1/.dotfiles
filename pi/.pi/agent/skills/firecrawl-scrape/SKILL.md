---
name: firecrawl-scrape
description: Use when you should extract clean markdown from one or more URLs.
allowed-tools:
  - Bash(firecrawl *)
  - Bash(npx firecrawl *)
disable-model-invocation: true
---

# firecrawl scrape

Scrape one or more URLs. Returns clean, LLM-optimized markdown. Multiple URLs are scraped concurrently.

## When to use

- You have a specific URL and want its content
- The page is static or JS-rendered (SPA)
- Step 2 in the [workflow escalation pattern](firecrawl-cli): search → **scrape** → map → crawl → interact

## Quick start

Use `$HOME/.config/firecrawl/.firecrawl/` for all Firecrawl file outputs. Do not run `mkdir` if it already exists; only create it when missing with `[ -d "$HOME/.config/firecrawl/.firecrawl" ] || mkdir -p "$HOME/.config/firecrawl/.firecrawl"`. Never create project-local `.firecrawl/`.

```bash
# Basic markdown extraction
firecrawl scrape "<url>" -o $HOME/.config/firecrawl/.firecrawl/page.md

# Main content only, no nav/footer
firecrawl scrape "<url>" --only-main-content -o $HOME/.config/firecrawl/.firecrawl/page.md

# Wait for JS to render, then scrape
firecrawl scrape "<url>" --wait-for 3000 -o $HOME/.config/firecrawl/.firecrawl/page.md

# Multiple URLs: use explicit output files instead of CLI defaults
firecrawl scrape "https://example.com" -o $HOME/.config/firecrawl/.firecrawl/example-home.md &
firecrawl scrape "https://example.com/blog" -o $HOME/.config/firecrawl/.firecrawl/example-blog.md &
firecrawl scrape "https://example.com/docs" -o $HOME/.config/firecrawl/.firecrawl/example-docs.md &
wait

# Get markdown and links together
firecrawl scrape "<url>" --format markdown,links -o $HOME/.config/firecrawl/.firecrawl/page.json

# Ask a question about the page
firecrawl scrape "https://example.com/pricing" --query "What is the enterprise plan price?"
```

## Options

| Option                   | Description                                                      |
| ------------------------ | ---------------------------------------------------------------- |
| `-f, --format <formats>` | Output formats: markdown, html, rawHtml, links, screenshot, json |
| `-Q, --query <prompt>`   | Ask a question about the page content (5 credits)                |
| `-H`                     | Include HTTP headers in output                                   |
| `--only-main-content`    | Strip nav, footer, sidebar — main content only                   |
| `--wait-for <ms>`        | Wait for JS rendering before scraping                            |
| `--include-tags <tags>`  | Only include these HTML tags                                     |
| `--exclude-tags <tags>`  | Exclude these HTML tags                                          |
| `-o, --output <path>`    | Output file path                                                 |

## Tips

- **Prefer plain scrape over `--query`.** Scrape to a file, then use `grep`, `head`, or read the markdown directly — you can search and reason over the full content yourself. Use `--query` only when you want a single targeted answer without saving the page (costs 5 extra credits).
- **Try scrape before interact.** Scrape handles static pages and JS-rendered SPAs. Only escalate to `interact` when you need interaction (clicks, form fills, pagination).
- Multiple URLs are scraped concurrently — check `firecrawl --status` for your concurrency limit.
- Single format outputs raw content. Multiple formats (e.g., `--format markdown,links`) output JSON.
- Always quote URLs — shell interprets `?` and `&` as special characters.
- Naming convention: `$HOME/.config/firecrawl/.firecrawl/{site}-{path}.md`

## See also

- [firecrawl-search](../firecrawl-search/SKILL.md) — find pages when you don't have a URL
- [firecrawl-interact](../firecrawl-interact/SKILL.md) — when scrape can't get the content, use `interact` to click, fill forms, etc.
- [firecrawl-download](../firecrawl-download/SKILL.md) — bulk download an entire site to local files
