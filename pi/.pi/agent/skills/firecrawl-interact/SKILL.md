---
name: firecrawl-interact
description: Use when you should interact with webpages through a live browser session.
allowed-tools:
  - Bash(firecrawl *)
  - Bash(npx firecrawl *)
disable-model-invocation: true
---

# firecrawl interact

Interact with scraped pages in a live browser session. Scrape a page first, then use natural language prompts or code to click, fill forms, navigate, and extract data.

## When to use

- Content requires interaction: clicks, form fills, pagination, login
- `scrape` failed because content is behind JavaScript interaction
- You need to navigate a multi-step flow
- Last resort in the [workflow escalation pattern](firecrawl-cli): search → scrape → map → crawl → **interact**
- **Never use interact for web searches** — use `search` instead

## Quick start

Use `$HOME/.config/firecrawl/.firecrawl/` for all Firecrawl file outputs. Do not run `mkdir` if it already exists; only create it when missing with `[ -d "$HOME/.config/firecrawl/.firecrawl" ] || mkdir -p "$HOME/.config/firecrawl/.firecrawl"`. Never create project-local `.firecrawl/`.

```bash
# 1. Scrape a page (scrape ID is saved automatically)
firecrawl scrape "<url>" -o $HOME/.config/firecrawl/.firecrawl/interact-page.md

# 2. Interact with the page using natural language
firecrawl interact --prompt "Click the login button" -o $HOME/.config/firecrawl/.firecrawl/interact-login.md
firecrawl interact --prompt "Fill in the email field with test@example.com" -o $HOME/.config/firecrawl/.firecrawl/interact-email.md
firecrawl interact --prompt "Extract the pricing table" -o $HOME/.config/firecrawl/.firecrawl/interact-pricing.md

# 3. Or use code for precise control
firecrawl interact --code "agent-browser click @e5" --language bash -o $HOME/.config/firecrawl/.firecrawl/interact-click.md
firecrawl interact --code "agent-browser snapshot -i" --language bash -o $HOME/.config/firecrawl/.firecrawl/interact-snapshot.md

# 4. Stop the session when done
firecrawl interact stop
```

## Options

| Option                | Description                                       |
| --------------------- | ------------------------------------------------- |
| `--prompt <text>`     | Natural language instruction (use this OR --code) |
| `--code <code>`       | Code to execute in the browser session            |
| `--language <lang>`   | Language for code: bash, python, node             |
| `--timeout <seconds>` | Execution timeout (default: 30, max: 300)         |
| `--scrape-id <id>`    | Target a specific scrape (default: last scrape)   |
| `-o, --output <path>` | Output file path                                  |

## Profiles

Use `--profile` on the scrape to persist browser state (cookies, localStorage) across scrapes:

```bash
# Session 1: Login and save state
firecrawl scrape "https://app.example.com/login" --profile my-app -o $HOME/.config/firecrawl/.firecrawl/my-app-login.md
firecrawl interact --prompt "Fill in email with user@example.com and click login" -o $HOME/.config/firecrawl/.firecrawl/my-app-login-interact.md

# Session 2: Come back authenticated
firecrawl scrape "https://app.example.com/dashboard" --profile my-app -o $HOME/.config/firecrawl/.firecrawl/my-app-dashboard.md
firecrawl interact --prompt "Extract the dashboard data" -o $HOME/.config/firecrawl/.firecrawl/my-app-dashboard-interact.md
```

Read-only reconnect (no writes to profile state):

```bash
firecrawl scrape "https://app.example.com" --profile my-app --no-save-changes -o $HOME/.config/firecrawl/.firecrawl/my-app-readonly.md
```

## Tips

- Always scrape first — `interact` requires a scrape ID from a previous `firecrawl scrape` call
- The scrape ID is saved automatically, so you don't need `--scrape-id` for subsequent interact calls
- Use `firecrawl interact stop` to free resources when done
- For parallel work, scrape multiple pages and interact with each using `--scrape-id`

## See also

- [firecrawl-scrape](../firecrawl-scrape/SKILL.md) — try scrape first, escalate to interact only when needed
- [firecrawl-search](../firecrawl-search/SKILL.md) — for web searches (never use interact for searching)
- [firecrawl-agent](../firecrawl-agent/SKILL.md) — AI-powered extraction (less manual control)
