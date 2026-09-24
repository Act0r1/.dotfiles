---
name: firecrawl-map
description: Use when you should discover URLs on a website.
allowed-tools:
  - Bash(firecrawl *)
  - Bash(npx firecrawl *)
disable-model-invocation: true
---

# firecrawl map

Discover URLs on a site. Use `--search` to find a specific page within a large site.

## When to use

- You need to find a specific subpage on a large site
- You want a list of all URLs on a site before scraping or crawling
- Step 3 in the [workflow escalation pattern](firecrawl-cli): search → scrape → **map** → crawl → interact

## Quick start

Use `$HOME/.config/firecrawl/.firecrawl/` for all Firecrawl file outputs. Do not run `mkdir` if it already exists; only create it when missing with `[ -d "$HOME/.config/firecrawl/.firecrawl" ] || mkdir -p "$HOME/.config/firecrawl/.firecrawl"`. Never create project-local `.firecrawl/`.

```bash
# Find a specific page on a large site
firecrawl map "<url>" --search "authentication" -o $HOME/.config/firecrawl/.firecrawl/filtered.txt

# Get all URLs
firecrawl map "<url>" --limit 500 --json -o $HOME/.config/firecrawl/.firecrawl/urls.json
```

## Options

| Option                            | Description                  |
| --------------------------------- | ---------------------------- |
| `--limit <n>`                     | Max number of URLs to return |
| `--search <query>`                | Filter URLs by search query  |
| `--sitemap <include\|skip\|only>` | Sitemap handling strategy    |
| `--include-subdomains`            | Include subdomain URLs       |
| `--json`                          | Output as JSON               |
| `-o, --output <path>`             | Output file path             |

## Tips

- **Map + scrape is a common pattern**: use `map --search` to find the right URL, then `scrape` it.
- Example: `map https://docs.example.com --search "auth"` → found `/docs/api/authentication` → `scrape` that URL.

## See also

- [firecrawl-scrape](../firecrawl-scrape/SKILL.md) — scrape the URLs you discover
- [firecrawl-crawl](../firecrawl-crawl/SKILL.md) — bulk extract instead of map + scrape
- [firecrawl-download](../firecrawl-download/SKILL.md) — download entire site (uses map internally)
