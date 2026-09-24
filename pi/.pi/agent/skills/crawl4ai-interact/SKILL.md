---
name: crawl4ai-interact
description: Interact with JavaScript-heavy web pages locally using Crawl4AI C4A-Script or JavaScript, including clicks, forms, waits, scrolling, browser profiles, screenshots, and Markdown extraction.
compatibility: Requires Crawl4AI 0.9.2 and its Playwright browser installed through the global uv tool.
---

# Crawl4AI interact

Use interaction only when a normal scrape cannot expose the required content.

## Output policy

Store scripts, Markdown, JSON, and screenshots in `$HOME/.config/crawl4ai/outputs/`, never in the current project unless requested.

```bash
[ -d "$HOME/.config/crawl4ai/outputs" ] || mkdir -p "$HOME/.config/crawl4ai/outputs"
```

## C4A-Script

Create `$HOME/.config/crawl4ai/outputs/interaction.c4a`:

```text
WAIT `#search` 10
CLICK `#search`
TYPE "Crawl4AI"
PRESS Enter
WAIT `.results` 10
```

Run it:

```bash
"$HOME/.pi/agent/skills/crawl4ai-interact/scripts/interact" \
  "https://example.com" \
  --c4a-file "$HOME/.config/crawl4ai/outputs/interaction.c4a" \
  --wait-for "css:.results" \
  --output "$HOME/.config/crawl4ai/outputs/result.md"
```

## JavaScript

```bash
"$HOME/.pi/agent/skills/crawl4ai-interact/scripts/interact" \
  "https://example.com" \
  --js-file "$HOME/.config/crawl4ai/outputs/interaction.js" \
  --scan-full-page \
  --screenshot "$HOME/.config/crawl4ai/outputs/result.png" \
  --output "$HOME/.config/crawl4ai/outputs/result.md"
```

## Options

- `--c4a-file PATH` or `--js-file PATH`
- `--before-js-file PATH` to trigger loading before a wait condition
- `--wait-for 'css:selector'` or `--wait-for 'js:() => condition'`
- `--wait-timeout MS`
- `--scan-full-page`
- `--profile-path PATH` for an existing persistent browser profile
- `--headful`
- `--screenshot PATH`
- `--format markdown|json`
- `--output PATH`, required

Prefer a manually authenticated persistent profile over writing credentials into scripts. Never retain passwords or tokens in generated scripts or output files.
