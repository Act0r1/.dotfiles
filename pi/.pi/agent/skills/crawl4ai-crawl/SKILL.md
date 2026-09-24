---
name: crawl4ai-crawl
description: Crawl multiple linked pages from a website locally with Crawl4AI using BFS, DFS, or Best-First traversal, depth/page limits, URL filters, and Markdown or JSON output.
compatibility: Requires Crawl4AI 0.9.2 installed through the global uv tool.
---

# Crawl4AI deep crawl

Use this skill to extract a website section or multiple linked pages. Prefer narrow include patterns and conservative limits.

## Output policy

Store generated files in `$HOME/.config/crawl4ai/outputs/`, never in the current project unless requested.

```bash
[ -d "$HOME/.config/crawl4ai/outputs" ] || mkdir -p "$HOME/.config/crawl4ai/outputs"
```

## Quick crawl

The CLI uses depth 3 internally:

```bash
crwl crawl "https://docs.example.com" \
  --deep-crawl bfs \
  --max-pages 20 \
  -o markdown \
  -O "$HOME/.config/crawl4ai/outputs/docs.md"
```

## Controlled crawl

Use the helper for explicit depth, path filters, external-link policy, or keyword-prioritized Best-First crawling:

```bash
"$HOME/.pi/agent/skills/crawl4ai-crawl/scripts/deep-crawl" \
  "https://docs.example.com" \
  --strategy bfs \
  --max-depth 2 \
  --max-pages 50 \
  --include-pattern "*/docs/*" \
  --exclude-pattern "*/changelog/*" \
  --format markdown \
  --output "$HOME/.config/crawl4ai/outputs/docs.md"
```

Best-First example:

```bash
"$HOME/.pi/agent/skills/crawl4ai-crawl/scripts/deep-crawl" \
  "https://example.com" \
  --strategy best-first \
  --keyword authentication \
  --keyword oauth \
  --max-depth 3 \
  --max-pages 30 \
  --format json \
  --output "$HOME/.config/crawl4ai/outputs/auth-pages.json"
```

## Options

- `--strategy bfs|dfs|best-first`
- `--max-depth N`
- `--max-pages N`
- `--include-pattern GLOB`, repeatable
- `--exclude-pattern GLOB`, repeatable
- `--keyword WORD`, repeatable, used by Best-First
- `--include-external`
- `--ignore-robots` only when the user explicitly requires it and the target permits crawling
- `--format markdown|json`
- `--output PATH`, required

Respect site terms and rate limits. Do not crawl an entire domain when a section is sufficient.
